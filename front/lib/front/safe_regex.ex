defmodule Front.SafeRegex do
  @moduledoc """
  Bounded regex matching used by parameter input format validation in
  the front-end controller. Mitigates ReDoS attacks via length caps,
  PCRE match limits, and a wall-clock timeout.

  > **Note:** `Scheduler.SafeRegex` (in the `periodic_scheduler` umbrella)
  > is the canonical copy. Keep this module's constants and behavior in
  > sync. Front does not currently expose `validate_pattern/1` because
  > patterns reach this app already validated by the scheduler.
  """

  require Logger

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
          | :crash

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

    case Task.yield(task, @timeout_ms) do
      {:ok, result} ->
        result

      nil ->
        case Task.shutdown(task, :brutal_kill) do
          {:ok, result} ->
            result

          nil ->
            {:error, :timeout}

          {:exit, reason} ->
            Logger.warning(
              "Front.SafeRegex match crashed pattern=#{inspect(pattern)} reason=#{inspect(reason)}"
            )

            {:error, :crash}
        end
    end
  end

  defp safe_run(pattern, value) do
    case :re.compile(pattern) do
      {:ok, compiled} -> run_compiled(compiled, value)
      {:error, _reason} -> {:error, :invalid_pattern}
    end
  end

  # `:report_errors` is required for the engine to surface `{:error,
  # :match_limit}` / `{:error, :match_limit_recursion}` instead of
  # silently returning `:nomatch` when the bound is exhausted.
  # See https://www.erlang.org/doc/apps/stdlib/re.html#run/3.
  defp run_compiled(compiled, value) do
    case :re.run(value, compiled, [
           {:match_limit, @match_limit},
           {:match_limit_recursion, @match_limit_recursion},
           :report_errors
         ]) do
      {:match, _captures} -> {:ok, true}
      :nomatch -> {:ok, false}
      {:error, :match_limit} -> {:error, :match_limit_exceeded}
      {:error, :match_limit_recursion} -> {:error, :match_limit_exceeded}
      {:error, _reason} -> {:error, :match_limit_exceeded}
    end
  end
end
