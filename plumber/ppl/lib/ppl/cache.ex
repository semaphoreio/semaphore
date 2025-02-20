defmodule Ppl.Cache do
  @moduledoc """
  Supervises cache processes
  """
  use Supervisor

  @caches [
    Ppl.Cache.OrganizationSettings
  ]

  def start_link(),
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_args),
    do: Supervisor.init(cache_modules(), strategy: :one_for_one)

  def cache_modules(), do: caches() |> Enum.into([], &elem(&1, 0))
  def cache_configs(), do: caches() |> Enum.into([], &elem(&1, 1))

  defp caches(), do: @caches |> Stream.map(&{&1, config(&1)}) |> Stream.filter(&enabled?/1)
  defp config(cache_module), do: Application.get_env(:ppl, cache_module, [])
  defp enabled?({_cache_module, config}), do: Keyword.get(config, :enabled?, false)
end
