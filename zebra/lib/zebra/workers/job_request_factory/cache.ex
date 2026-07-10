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
    skipped(:no_cache_id)
    {:ok, nil}
  end

  def find(cache_id, repo_proxy, org_id, job_type) do
    Watchman.benchmark("external.cachehub.describe", fn ->
      req = Request.new(cache_id: cache_id)

      with false <- skip_cache?(repo_proxy, org_id, job_type),
           {:ok, endpoint} <- Application.fetch_env(:zebra, :cachehub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- grpc_describe(channel, req) do
        handle_describe_response(response, cache_id)
      else
        true ->
          Logger.info(
            "Skipping fetching of the cache as the job is part of Forked PR build. Cache id #{inspect(cache_id)}"
          )

          skipped(:forked_pr)
          {:ok, nil}

        e ->
          Logger.warning(
            "Failed to fetch info from cachehub. cache_id=#{cache_id} error=#{inspect(e)}"
          )

          failed(:grpc_error)
          {:ok, nil}
      end
    end)
  end

  defp grpc_describe(channel, req),
    do: Stub.describe(channel, req, timeout: 30_000),
    after: GRPC.Stub.disconnect(channel)

  defp handle_describe_response(response, cache_id) do
    ok_code = InternalApi.ResponseStatus.Code.value(:OK)

    cond do
      response.status.code != ok_code ->
        Logger.warning(
          "Cachehub describe returned non-OK status. cache_id=#{cache_id} status_code=#{inspect(response.status.code)}"
        )

        failed(:non_ok_response)
        {:ok, nil}

      is_nil(response.cache) or blank?(response.cache.credential) ->
        Logger.warning("Cachehub describe returned blank credential. cache_id=#{cache_id}")

        failed(:blank_credential)
        {:ok, nil}

      true ->
        {:ok, response.cache}
    end
  end

  defp blank?(nil), do: true
  defp blank?(credential), do: String.trim(credential) == ""

  defp failed(reason) do
    Watchman.increment({"external.cachehub.describe.failed", [to_string(reason)]})
  end

  defp skipped(reason) do
    Watchman.increment({"external.cachehub.describe.skipped", [to_string(reason)]})
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

  def forked_pr?(_repo = %{pr_slug: ""}), do: false
  def forked_pr?(nil), do: false

  def forked_pr?(repo) do
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
