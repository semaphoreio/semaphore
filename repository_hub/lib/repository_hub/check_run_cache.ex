defmodule RepositoryHub.CheckRunCache do
  @moduledoc """
  Per-pod cache of the check-run each pipeline reports to, keyed by
  (owner, repo, sha, context, source_id).

  Without it every status update first lists the commit's check-runs to find
  the pipeline's run, which doubles the GitHub API calls per update. A hit
  skips that lookup and goes straight to the update.

  The value is the run's id and the status Semaphore last wrote to it. The
  cache is per pod, so another pod may have completed the run since; ordering
  across pods is `RepositoryHub.BuildStatusGuard`'s job (it skips a PENDING
  that arrives after the pipeline's terminal status). A request without a
  source_id is never cached: every pipeline then shares one external_id, so
  the run can't be tied to a pipeline.

  A miss, or a dropped entry after a failed write, falls back to the lookup.
  """

  @cache :check_run_cache
  @ttl_ms :timer.hours(1)

  @type key :: {String.t(), String.t(), String.t(), String.t(), String.t()} | nil

  def child_spec(_opts) do
    import Cachex.Spec

    %{
      id: __MODULE__,
      start: {Cachex, :start_link, [@cache, [expiration: expiration(default: @ttl_ms)]]}
    }
  end

  @spec key(map(), map()) :: key()
  def key(%{source_id: source_id}, _repository) when source_id in [nil, ""], do: nil

  def key(request, repository),
    do: {repository.owner, repository.name, request.commit_sha, request.context, request.source_id}

  @doc ~S|Returns the cached run as `%{"id" => id, "status" => status}`, or `:miss`.|
  @spec get(key()) :: {:ok, map()} | :miss
  def get(nil), do: :miss

  def get(key) do
    case Cachex.get(@cache, key) do
      {:ok, %{} = run} -> {:ok, run}
      _ -> :miss
    end
  end

  @spec put(key(), integer(), String.t()) :: :ok
  def put(nil, _id, _status), do: :ok

  def put(key, id, status) do
    Cachex.put(@cache, key, %{"id" => id, "status" => status})
    :ok
  end

  @spec delete(key()) :: :ok
  def delete(nil), do: :ok

  def delete(key) do
    Cachex.del(@cache, key)
    :ok
  end

  def clear, do: Cachex.clear(@cache)
end
