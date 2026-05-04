defmodule Scheduler.SafeRegex do
  @moduledoc """
  Bounded regex matching used by parameter input format validation.

  Mitigates ReDoS attacks by enforcing:

  - a maximum pattern length (#{512} bytes),
  - a maximum value length (#{4096} bytes),
  - PCRE's built-in `match_limit` (default 10,000,000) — a runaway
    match returns `:nomatch` instead of consuming unbounded CPU.

  > **Note:** `Front.SafeRegex` (in the `front` umbrella) is a near-byte-for-byte
  > copy of this module. Keep the constants and behavior in sync; both
  > services share the same trust boundary.
  """

  @max_pattern_length 512
  @max_value_length 4_096

  @type match_error ::
          :pattern_too_long
          | :value_too_long
          | :invalid_pattern

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
  Matches `value` against `pattern` under length-bounded execution.

  Returns `{:ok, boolean}` on success or `{:error, reason}` when the
  pattern, value, or compile step is rejected. Callers should treat any
  error as "value does not match" (fail-closed) and surface a
  user-friendly message.
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
        run(pattern, value)
    end
  end

  defp run(pattern, value) do
    case :re.compile(pattern) do
      {:ok, compiled} ->
        case :re.run(value, compiled) do
          {:match, _captures} -> {:ok, true}
          :nomatch -> {:ok, false}
        end

      {:error, _reason} ->
        {:error, :invalid_pattern}
    end
  end
end
