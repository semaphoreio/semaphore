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

  @fresh_ttl_ms 5_000

  @doc """
  Short-lived lookup for authorization gates (DeploymentTargets.Verify).

  Unlike `check_roles/2`, whose entries live for the configured expiration
  TTL, a result here is reused for at most #{@fresh_ttl_ms} ms, so a role
  granted or revoked in RBAC takes effect within that window. Concurrent
  identical lookups share one RBAC call. Errors are never cached, and when
  the cache is not running RBAC is called directly.
  """
  def check_roles_fresh(_subject, []), do: {:ok, %{}}

  def check_roles_fresh(subject = %Subject{}, role_ids) do
    Watchman.benchmark(metrics_key("fresh.duration"), fn ->
      cache = config(:cache_name)
      key = fresh_key(subject, role_ids)

      case Cachex.get(cache, key) do
        {:ok, {fetched_at, assignments}} ->
          use_or_refresh(fetched_at, assignments, cache, key, subject, role_ids)

        {:ok, nil} ->
          fetch_fresh(cache, key, subject, role_ids)

        {:error, _reason} ->
          Client.check_roles(subject, role_ids)
      end
    end)
  end

  defp use_or_refresh(fetched_at, assignments, cache, key, subject, role_ids) do
    if fresh?(fetched_at) do
      Watchman.increment(metrics_key("fresh.hits"))
      {:ok, assignments}
    else
      Cachex.del(cache, key)
      fetch_fresh(cache, key, subject, role_ids)
    end
  end

  defp fetch_fresh(cache, key, subject, role_ids) do
    Watchman.increment(metrics_key("fresh.misses"))

    fallback = fn ->
      fetched_at = System.monotonic_time(:millisecond)

      case Client.check_roles(subject, role_ids) do
        {:ok, assignments} -> {:commit, {fetched_at, assignments}}
        {:error, reason} -> {:ignore, {:error, reason}}
      end
    end

    case Cachex.fetch(cache, key, fallback) do
      {:commit, {_fetched_at, assignments}} ->
        Cachex.expire(cache, key, @fresh_ttl_ms)
        {:ok, assignments}

      {:ok, {_fetched_at, assignments}} ->
        {:ok, assignments}

      {:ignore, {:error, reason}} ->
        {:error, reason}

      {:error, _reason} ->
        Client.check_roles(subject, role_ids)
    end
  end

  defp fresh?(fetched_at),
    do: System.monotonic_time(:millisecond) - fetched_at < @fresh_ttl_ms

  defp fresh_key(subject = %Subject{}, role_ids),
    do: {:fresh, subject_to_key(subject), role_ids |> Enum.uniq() |> Enum.sort()}

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
