defmodule Ppl.Retention.Policy.State do
  @moduledoc false

  defstruct [:sleep_ms, :paused_until]

  @default_sleep_ms 1_000

  def new(opts \\ []) do
    %__MODULE__{
      sleep_ms: opts[:sleep_ms] || @default_sleep_ms,
      paused_until: nil
    }
  end

  def from_env(module) do
    config = Application.get_env(:ppl, module, [])
    new(sleep_ms: Keyword.get(config, :sleep_ms, @default_sleep_ms))
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
      {:sleep_ms, v}, s when is_integer(v) -> %{s | sleep_ms: v}
      _, s -> s
    end)
  end

  def to_config(state), do: %{sleep_ms: state.sleep_ms}
end
