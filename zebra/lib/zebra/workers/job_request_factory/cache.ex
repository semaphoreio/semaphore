defmodule Zebra.Workers.JobRequestFactory.Cache do
  require Logger
  alias InternalApi.Cache.DescribeRequest, as: Request
  alias InternalApi.Cache.CacheService.Stub

  alias Zebra.Workers.JobRequestFactory.JobRequest
  alias Zebra.Workers.JobRequestFactory.Machine

  #
  # If cache_id is nil, we skip injecting cache information,
  # If cache is not found, we skip injecting cache information,
  #
  # Overall, if cache system is down, we ignore every issue.
  #

  def find(cache_id, repo_proxy, org_id, job_type \\ :pipeline_job)

  def find(nil, _repo_proxy, _org_id, _job_type) do
    # We don't fail any jobs due to a missing cache connection,
    # but we should make sure we are aware of any issues in this area.
    Watchman.increment("external.cachehub.describe.failed")

    {:ok, nil}
  end

  def find(cache_id, repo_proxy, org_id, job_type) do
    Watchman.benchmark("external.cachehub.describe", fn ->
      req = Request.new(cache_id: cache_id)

      with false <- skip_cache?(repo_proxy, org_id, job_type),
           {:ok, endpoint} <- Application.fetch_env(:zebra, :cachehub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- Stub.describe(channel, req, timeout: 30_000) do
        if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
          if response.cache && response.cache.credential != " " do
            {:ok, response.cache}
          else
            {:ok, nil}
          end
        else
          {:ok, nil}
        end
      else
        true ->
          Logger.info(
            "Skipping fetching of the cache as the job is part of Forked PR build. Cache id #{inspect(cache_id)}"
          )

          {:ok, nil}

        e ->
          Watchman.increment("external.cachehub.describe.failed")
          Logger.info("Failed to fetch info from cachehub #{cache_id}, #{inspect(e)}")

          {:ok, nil}
      end
    end)
  end

  def files(_, nil), do: {:ok, []}

  def files(job, cache) do
    path = "#{Machine.home_path(job)}/.ssh/semaphore_cache_key"

    {:ok,
     [
       JobRequest.file(path, cache.credential, "0600")
     ]}
  end

  def env_vars(_, nil, _), do: {:ok, []}

  def env_vars(job, cache, organization_id) do
    path = "#{Machine.home_path(job)}/.ssh/semaphore_cache_key"
    user = String.replace(cache.id, "-", "")

    vars = [
      JobRequest.env_var("SSH_PRIVATE_KEY_PATH", path),
      JobRequest.env_var("SEMAPHORE_CACHE_BACKEND", "sftp"),
      JobRequest.env_var("SEMAPHORE_CACHE_PRIVATE_KEY_PATH", path),
      JobRequest.env_var("SEMAPHORE_CACHE_USERNAME", user),
      JobRequest.env_var("SEMAPHORE_CACHE_URL", cache.url)
    ]

    if FeatureProvider.feature_enabled?(:cache_cli_parallel_archive_method,
         param: organization_id
       ) do
      {:ok,
       vars ++
         [
           JobRequest.env_var("SEMAPHORE_CACHE_ARCHIVE_METHOD", "native-parallel")
         ]}
    else
      {:ok, vars}
    end
  end

  defp forked_pr?(_repo = %{pr_slug: ""}), do: false
  defp forked_pr?(nil), do: false

  defp forked_pr?(repo) do
    if approval_enable_cache?(repo) do
      false
    else
      forked_pr_without_approval_override?(repo)
    end
  end

  defp forked_pr_without_approval_override?(_repo = %{pr_slug: ""}), do: false
  defp forked_pr_without_approval_override?(nil), do: false

  defp forked_pr_without_approval_override?(repo) do
    [pr_repo | _rest] = repo.pr_slug |> String.split("/")
    [base_repo | _rest] = repo.repo_slug |> String.split("/")
    pr_repo != base_repo
  end

  defp skip_cache?(repo_proxy, org_id, :debug_job) do
    forked_pr_without_approval_override?(repo_proxy) and
      FeatureProvider.feature_enabled?(:disable_forked_pr_cache, param: org_id)
  end

  defp skip_cache?(repo_proxy, org_id, _job_type) do
    forked_pr?(repo_proxy) and
      FeatureProvider.feature_enabled?(:disable_forked_pr_cache, param: org_id)
  end

  defp approval_enable_cache?(nil), do: false

  defp approval_enable_cache?(repo) do
    Map.get(repo, :approval_enable_cache, false)
  end
end
