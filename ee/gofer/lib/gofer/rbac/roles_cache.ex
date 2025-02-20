defmodule Gofer.RBAC.RolesCache do
  @moduledoc """
  Caches roles assignments retrieved from RBAC
  """

  alias Gofer.RBAC.Client
  alias Gofer.RBAC.Subject
  require Cachex.Spec

  defp config(key), do: Application.get_env(:gofer, __MODULE__) |> Keyword.fetch!(key)
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

  def check_roles(_subject, []), do: {:ok, %{}}

  def check_roles(subject = %Subject{}, role_ids) do
    Watchman.benchmark(metrics_key(:duration), fn ->
      cached_assignments = fetch_cached_assignments(subject)
      cached_role_ids = MapSet.new(cached_assignments, &elem(&1, 0))
      all_role_ids = MapSet.new(role_ids) |> MapSet.union(cached_role_ids)

      if MapSet.new(role_ids) |> MapSet.subset?(cached_role_ids) do
        Watchman.increment(metrics_key(:hits))

        {:ok, Map.take(cached_assignments, role_ids)}
      else
        Watchman.increment(metrics_key(:misses))

        case update_cache(subject, all_role_ids) do
          {:ok, assignments} -> {:ok, Map.take(assignments, role_ids)}
          {:error, reason} -> {:error, reason}
        end
      end
    end)
  end

  defp fetch_cached_assignments(subject = %Subject{}) do
    case Cachex.get(config(:cache_name), subject_to_key(subject)) do
      {:ok, nil} -> %{}
      {:ok, result} -> result
    end
  end

  defp update_cache(subject = %Subject{}, role_ids) do
    case Client.check_roles(subject, role_ids) do
      {:ok, assignments} ->
        Cachex.put(config(:cache_name), subject_to_key(subject), assignments)
        {:ok, assignments}

      {:error, reason} ->
        Cachex.del(config(:cache_name), subject_to_key(subject))
        {:error, reason}
    end
  end

  defp subject_to_key(subject = %Subject{}),
    do: "#{subject.organization_id}/#{subject.project_id}/#{subject.triggerer}"
end
