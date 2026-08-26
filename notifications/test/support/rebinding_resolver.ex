defmodule Support.RebindingResolver do
  @moduledoc """
  A stateful, offline resolver that models a DNS-rebinding attacker: the first
  lookup of a host answers a PUBLIC IP (so the egress guard admits it), and
  every subsequent lookup of that host answers a PRIVATE IP (what the attacker
  would hand the HTTP client at connect time).

  Used only by the rebinding regression test to prove the guard pins the IP it
  vetted instead of letting the client re-resolve. Start it with `start/0`,
  point `:egress_resolver` at `{Support.RebindingResolver, :resolve}`, and the
  Nth call for a host returns the Nth entry (last entry sticks).
  """

  use Agent

  @public {93, 184, 216, 34}
  @private {10, 0, 0, 5}

  def start do
    case Agent.start_link(fn -> %{} end, name: __MODULE__) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  def reset, do: Agent.update(__MODULE__, fn _ -> %{} end)

  @doc "Count of resolutions performed for `host` so far."
  def call_count(host), do: Agent.get(__MODULE__, fn state -> Map.get(state, host, 0) end)

  def resolve(host) do
    n =
      Agent.get_and_update(__MODULE__, fn state ->
        {Map.get(state, host, 0), Map.update(state, host, 1, &(&1 + 1))}
      end)

    ip = if n == 0, do: @public, else: @private
    {:ok, [ip]}
  end
end
