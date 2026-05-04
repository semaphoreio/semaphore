defmodule Front.SafeRegex do
  @moduledoc """
  Bounded regex matching used by parameter input format validation in
  the front-end controller.

  Mitigates ReDoS attacks by enforcing:

  - a maximum pattern length (#{512} bytes),
  - a maximum value length (#{4096} bytes),
  - PCRE's built-in `match_limit` (default 10,000,000) — a runaway
    match returns `:nomatch` instead of consuming unbounded CPU.

  > **Note:** `Scheduler.SafeRegex` (in the `periodic_scheduler` umbrella)
  > is the canonical copy. Keep this module's constants and behavior in
  > sync. Front does not currently expose `validate_pattern/1` because
  > patterns reach this app already validated by the scheduler.
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
  Matches `value` against `pattern` under length-bounded execution.

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
