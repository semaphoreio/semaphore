defmodule Front.SafeRegex do
  @moduledoc """
  Bounded regex matching used by parameter input format validation in
  the front-end controller. Mitigates ReDoS attacks via length caps,
  PCRE match limits, and a wall-clock timeout.
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
  Matches `value` against `pattern` under bounded execution.

  Returns `{:ok, boolean}` or `{:error, reason}`. Callers should treat
  any error as "value does not match" (fail-closed).
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
