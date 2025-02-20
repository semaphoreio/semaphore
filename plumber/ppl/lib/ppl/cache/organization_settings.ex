defmodule Ppl.Cache.OrganizationSettings do
  @moduledoc """
  Caches roles assignments retrieved from RBAC
  """

  alias Ppl.OrgClient
  require Cachex.Spec

  defp config(key), do: Application.get_env(:ppl, __MODULE__) |> Keyword.fetch!(key)
  defp metrics_prefix(), do: "cache.#{config(:cache_name)}"
  defp metrics_key(metrics_suffix), do: "#{metrics_prefix()}.#{metrics_suffix}"

  def start_link(_args) do
    Cachex.start_link(config(:cache_name),
      expiration:
        Cachex.Spec.expiration(
          default: :timer.seconds(config(:expiration_ttl)),
          interval: :timer.seconds(config(:expiration_interval)),
          lazy: true
        ),
      limit:
        Cachex.Spec.limit(
          size: config(:size_limit),
          policy: Cachex.Policy.LRW,
          reclaim: config(:reclaim_coef)
        ),
      stats: true
    )
  end

  def child_spec(_opts),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}}

  def get(_org_id, []), do: {:ok, %{}}

  def get(org_id, keys) do
    Watchman.benchmark(metrics_key(:duration), fn ->
      cached_settings = get_cached_settings(org_id)
      cached_setting_keys = MapSet.new(cached_settings, &elem(&1, 0))

      result =
        if MapSet.new(keys) |> MapSet.subset?(cached_setting_keys) do
          Watchman.increment(metrics_key(:hits))
          {:ok, cached_settings}
        else
          Watchman.increment(metrics_key(:misses))
          update_cache(org_id)
        end

      case result do
        {:ok, settings} -> {:ok, Map.take(settings, keys)}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp get_cached_settings(org_id) do
    case Cachex.get(config(:cache_name), org_id) do
      {:ok, nil} -> %{}
      {:ok, result} -> result
    end
  end

  defp update_cache(org_id) do
    case OrgClient.fetch_settings(org_id) do
      {:ok, settings} ->
        Cachex.put(config(:cache_name), org_id, settings)
        {:ok, settings}

      {:error, reason} ->
        Cachex.del(config(:cache_name), org_id)
        {:error, reason}
    end
  end
end
