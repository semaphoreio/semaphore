defmodule Ppl.Retention.Deleter.State do
  @moduledoc false

  defstruct [:interval_ms, :batch_size, :paused_until]

  @default_interval_ms 30_000
  @default_batch_size 100

  def new(opts \\ []) do
    %__MODULE__{
      interval_ms: opts[:interval_ms] || @default_interval_ms,
      batch_size: opts[:batch_size] || @default_batch_size,
      paused_until: nil
    }
  end

  def from_env(module) do
    config = Application.get_env(:ppl, module, [])

    interval_ms =
      case Keyword.get(config, :sleep_period_sec) do
        nil -> @default_interval_ms
        sec -> sec * 1000
      end

    new(
      interval_ms: interval_ms,
      batch_size: Keyword.get(config, :batch_size, @default_batch_size)
    )
  end

  def pause(state), do: %{state | paused_until: :infinity}

  def pause_for(state, ms) when is_integer(ms) and ms > 0 do
    %{state | paused_until: System.monotonic_time(:millisecond) + ms}
  end

  def resume(state), do: %{state | paused_until: nil}

  def check_pause(%{paused_until: nil} = state), do: {:running, state}
  def check_pause(%{paused_until: :infinity} = state), do: {:paused, state}

  def check_pause(%{paused_until: paused_until} = state) do
    if System.monotonic_time(:millisecond) >= paused_until do
      {:running, %{state | paused_until: nil}}
    else
      {:paused, state}
    end
  end

  def update(state, opts) do
    Enum.reduce(opts, state, fn
      {:interval_ms, v}, s when is_integer(v) -> %{s | interval_ms: v}
      {:batch_size, v}, s when is_integer(v) -> %{s | batch_size: v}
      _, s -> s
    end)
  end

  def to_config(state) do
    %{interval_ms: state.interval_ms, batch_size: state.batch_size}
  end
end
