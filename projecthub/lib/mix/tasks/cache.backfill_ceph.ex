defmodule Mix.Tasks.Cache.BackfillCeph do
  use Mix.Task

  import Ecto.Query

  alias Projecthub.Cache
  alias Projecthub.Models.Project
  alias Projecthub.Repo

  @shortdoc "Queues CacheHub Ceph provisioning for existing project caches"

  @switches [
    org_id: :keep,
    project_id: :keep,
    batch_size: :integer,
    max_concurrency: :integer,
    limit: :integer,
    allow_failures: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: @switches)

    batch_size = positive(opts[:batch_size], 100)
    max_concurrency = positive(opts[:max_concurrency], 10)
    limit = opts[:limit]
    allow_failures = opts[:allow_failures] || false
    org_ids = Keyword.get_values(opts, :org_id)
    project_ids = Keyword.get_values(opts, :project_id)

    projects = load_projects(org_ids, project_ids, limit)
    total = length(projects)

    Mix.shell().info("Found #{total} project caches for Ceph provisioning")

    result =
      projects
      |> Enum.chunk_every(batch_size)
      |> Enum.reduce(%{total: total, queued: 0, failed: []}, fn batch, acc ->
        batch_result = enqueue_batch(batch, max_concurrency)

        %{
          acc
          | queued: acc.queued + batch_result.queued,
            failed: acc.failed ++ batch_result.failed
        }
      end)

    print_summary(result)

    if result.failed != [] and not allow_failures do
      Mix.raise("Failed to queue #{length(result.failed)} cache(s) for Ceph provisioning")
    end
  end

  defp load_projects(org_ids, project_ids, limit) do
    Project
    |> where([p], not is_nil(p.cache_id))
    |> where([p], is_nil(p.deleted_at))
    |> maybe_filter_org_ids(org_ids)
    |> maybe_filter_project_ids(project_ids)
    |> order_by([p], asc: p.organization_id, asc: p.id)
    |> maybe_limit(limit)
    |> Repo.all()
  end

  defp enqueue_batch(projects, max_concurrency) do
    projects
    |> Task.async_stream(&enqueue_project/1, ordered: false, max_concurrency: max_concurrency, timeout: 30_000)
    |> Enum.reduce(%{queued: 0, failed: []}, fn
      {:ok, {:ok, _project_id}}, acc ->
        %{acc | queued: acc.queued + 1}

      {:ok, {:error, {project_id, reason}}}, acc ->
        %{acc | failed: [%{project_id: project_id, reason: reason} | acc.failed]}

      {:exit, reason}, acc ->
        %{acc | failed: [%{project_id: "unknown", reason: inspect(reason)} | acc.failed]}
    end)
  end

  defp enqueue_project(project) do
    case Cache.provision_ceph_cache(project.cache_id, project.organization_id, project.id, project.name) do
      {:ok, _} -> {:ok, project.id}
      {:error, reason} -> {:error, {project.id, inspect(reason)}}
    end
  end

  defp maybe_filter_org_ids(query, []), do: query
  defp maybe_filter_org_ids(query, ids), do: where(query, [p], p.organization_id in ^ids)

  defp maybe_filter_project_ids(query, []), do: query
  defp maybe_filter_project_ids(query, ids), do: where(query, [p], p.id in ^ids)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit) when is_integer(limit) and limit > 0, do: limit(query, [p], ^limit)
  defp maybe_limit(query, _), do: query

  defp positive(value, _default) when is_integer(value) and value > 0, do: value
  defp positive(_, default), do: default

  defp print_summary(result) do
    Mix.shell().info("Ceph backfill summary:")
    Mix.shell().info("  total=#{result.total}")
    Mix.shell().info("  queued=#{result.queued}")
    Mix.shell().info("  failed=#{length(result.failed)}")

    Enum.each(Enum.reverse(result.failed), fn failure ->
      Mix.shell().info("  failure project_id=#{failure.project_id} reason=#{failure.reason}")
    end)
  end
end
