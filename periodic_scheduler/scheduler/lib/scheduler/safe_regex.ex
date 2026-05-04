defmodule Scheduler.SafeRegex do
  @moduledoc """
  Bounded regex matching used by parameter input format validation.

  Mitigates ReDoS attacks by enforcing:

  - a maximum pattern length (#{512} bytes),
  - a maximum value length (#{4096} bytes),
  - PCRE `match_limit` and `match_limit_recursion` caps,
  - a wall-clock timeout via `Task.async/Task.shutdown`.
  """

  @max_pattern_length 512
  @max_value_length 4_096
  @match_limit 100_000
  @match_limit_recursion 5_000
  @timeout_ms 100

  @type match_error ::
          :pattern_too_long
          | :value_too_long
          | :invalid_pattern
          | :match_limit_exceeded
          | :timeout

  @spec max_pattern_length() :: pos_integer()
  def max_pattern_length, do: @max_pattern_length

  @spec max_value_length() :: pos_integer()
  def max_value_length, do: @max_value_length

  @doc """
  Validates that `pattern` compiles and stays within the safe length bound.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate_pattern(String.t() | nil) :: :ok | {:error, match_error()}
  def validate_pattern(nil), do: {:error, :invalid_pattern}
  def validate_pattern(""), do: {:error, :invalid_pattern}

  def validate_pattern(pattern) when is_binary(pattern) do
    cond do
      byte_size(pattern) > @max_pattern_length ->
        {:error, :pattern_too_long}

      true ->
        case :re.compile(pattern) do
          {:ok, _compiled} -> :ok
          {:error, _reason} -> {:error, :invalid_pattern}
        end
    end
  end

  @doc """
  Matches `value` against `pattern` under bounded execution.

  Returns `{:ok, boolean}` on success or `{:error, reason}` on a guard
  trip. Callers should treat any error as "value does not match"
  (fail-closed) and surface a user-friendly message.
  """
  @spec match(String.t() | nil, String.t() | nil) ::
          {:ok, boolean()} | {:error, match_error()}
  def match(nil, _value), do: {:error, :invalid_pattern}
  def match(_pattern, nil), do: {:ok, false}

  def match(pattern, value) when is_binary(pattern) and is_binary(value) do
    cond do
      byte_size(pattern) > @max_pattern_length ->
        {:error, :pattern_too_long}

      byte_size(value) > @max_value_length ->
        {:error, :value_too_long}

      true ->
        bounded_match(pattern, value)
    end
  end

  defp bounded_match(pattern, value) do
    task = Task.async(fn -> safe_run(pattern, value) end)

    case Task.yield(task, @timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        {:error, :timeout}

      {:exit, _reason} ->
        {:error, :timeout}
    end
  end

  defp safe_run(pattern, value) do
    with {:ok, compiled} <- :re.compile(pattern),
         result <-
           :re.run(value, compiled,
             match_limit: @match_limit,
             match_limit_recursion: @match_limit_recursion
           ) do
      case result do
        {:match, _captures} -> {:ok, true}
        :nomatch -> {:ok, false}
        {:error, _reason} -> {:error, :match_limit_exceeded}
      end
    else
      {:error, _reason} -> {:error, :invalid_pattern}
    end
  end
end
