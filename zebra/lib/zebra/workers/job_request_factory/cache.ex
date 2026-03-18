defmodule Zebra.Workers.JobRequestFactory.Cache do
  require Logger

  alias InternalApi.Cache.DescribeRequest, as: Request
  alias InternalApi.Cache.CacheService.Stub

  alias Zebra.Workers.JobRequestFactory.JobRequest
  alias Zebra.Workers.JobRequestFactory.Machine

  @max_role_session_name_length 64

  #
  # If cache_id is nil, we skip injecting cache information,
  # If cache is not found, we skip injecting cache information,
  #
  # Overall, if cache system is down, we ignore every issue.
  #

  def find(nil, _repo_proxy, _org_id) do
    # We don't fail any jobs due to a missing cache connection,
    # but we should make sure we are aware of any issues in this area.
    Watchman.increment("external.cachehub.describe.failed")

    {:ok, nil}
  end

  def find(cache_id, repo_proxy, org_id) do
    Watchman.benchmark("external.cachehub.describe", fn ->
      req = Request.new(cache_id: cache_id)

      with false <-
             forked_pr?(repo_proxy) and
               FeatureProvider.feature_enabled?(:disable_forked_pr_cache, param: org_id),
           {:ok, endpoint} <- Application.fetch_env(:zebra, :cachehub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- Stub.describe(channel, req, timeout: 30_000) do
        if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
          normalize_described_cache(response.cache)
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
    case cache_backend(cache) do
      :ceph ->
        {:ok, []}

      :sftp ->
        path = "#{Machine.home_path(job)}/.ssh/semaphore_cache_key"

        {:ok,
         [
           JobRequest.file(path, cache.credential, "0600")
         ]}
    end
  end

  def env_vars(_, nil, _, _, _), do: {:ok, []}

  def env_vars(job, cache, organization_id, repo_proxy, job_type) do
    case cache_backend(cache) do
      :ceph ->
        ceph_env_vars(job, cache, organization_id, repo_proxy, job_type)

      :sftp ->
        sftp_env_vars(job, cache, organization_id)
    end
  end

  @doc false
  def session_name_for_job(job_id, read_only?) do
    mode = if read_only?, do: "ro", else: "rw"

    "zebra-#{mode}-#{job_id}"
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9+=,.@-]/, "-")
    |> String.slice(0, @max_role_session_name_length)
  end

  defp sftp_env_vars(job, cache, organization_id) do
    path = "#{Machine.home_path(job)}/.ssh/semaphore_cache_key"
    user = String.replace(cache.id, "-", "")

    vars = [
      JobRequest.env_var("SSH_PRIVATE_KEY_PATH", path),
      JobRequest.env_var("SEMAPHORE_CACHE_BACKEND", "sftp"),
      JobRequest.env_var("SEMAPHORE_CACHE_PRIVATE_KEY_PATH", path),
      JobRequest.env_var("SEMAPHORE_CACHE_USERNAME", user),
      JobRequest.env_var("SEMAPHORE_CACHE_URL", cache.url)
    ]

    if FeatureProvider.feature_enabled?(:cache_cli_parallel_archive_method, param: organization_id) do
      {:ok,
       vars ++
         [
           JobRequest.env_var("SEMAPHORE_CACHE_ARCHIVE_METHOD", "native-parallel")
         ]}
    else
      {:ok, vars}
    end
  end

  defp ceph_env_vars(job, cache, organization_id, repo_proxy, job_type) do
    read_only? = read_only_cache_access?(repo_proxy, job_type)
    role_arn = if read_only?, do: cache.ro_role_arn, else: cache.rw_role_arn

    with false <- blank?(role_arn),
         false <- blank?(cache.bucket),
         {:ok, s3_endpoint} <- ceph_endpoint(),
         {:ok, credentials} <-
           sts_client_module().assume_role(
             role_arn,
             session_name_for_job(job.id, read_only?),
             assume_role_duration_seconds(job_type)
           ) do
      vars = [
        JobRequest.env_var("SEMAPHORE_CACHE_BACKEND", "s3"),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_URL", s3_endpoint),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_BUCKET", cache.bucket),
        JobRequest.env_var("AWS_ACCESS_KEY_ID", credentials.access_key_id),
        JobRequest.env_var("AWS_SECRET_ACCESS_KEY", credentials.secret_access_key),
        JobRequest.env_var("AWS_SESSION_TOKEN", credentials.session_token)
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
    else
      true ->
        {:ok, []}

      {:error, reason} ->
        Watchman.increment("external.cachehub.ceph_sts.failed")

        Logger.error(
          "Failed to assume Ceph role for cache_id=#{cache.id} role_arn=#{role_arn} reason=#{inspect(reason)}"
        )

        {:ok, []}

      e ->
        Watchman.increment("external.cachehub.ceph_sts.failed")

        Logger.error(
          "Failed to configure Ceph cache for cache_id=#{cache.id} role_arn=#{role_arn} reason=#{inspect(e)}"
        )

        {:ok, []}
    end
  end

  defp normalize_described_cache(nil), do: {:ok, nil}

  defp normalize_described_cache(cache) do
    cond do
      ceph_cache_ready?(cache) -> {:ok, cache}
      sftp_cache_ready?(cache) -> {:ok, cache}
      true -> {:ok, nil}
    end
  end

  defp ceph_cache_ready?(cache) do
    cache_backend(cache) == :ceph and
      cache.state == InternalApi.Cache.CacheState.value(:READY) and
      not blank?(cache.bucket) and
      not blank?(cache.ro_role_arn) and
      not blank?(cache.rw_role_arn)
  end

  defp sftp_cache_ready?(cache) do
    cache_backend(cache) == :sftp and not blank?(cache.credential)
  end

  defp cache_backend(cache) do
    if cache.backend == InternalApi.Cache.Backend.value(:CEPH), do: :ceph, else: :sftp
  end

  defp ceph_endpoint do
    endpoint = System.get_env("CEPH_ENDPOINT") |> to_string() |> String.trim_trailing("/")

    if endpoint == "" do
      {:error, :missing_ceph_endpoint}
    else
      {:ok, endpoint}
    end
  end

  defp sts_client_module do
    Application.get_env(:zebra, :ceph_sts_client_module, Zebra.Workers.JobRequestFactory.CephSts)
  end

  defp read_only_cache_access?(repo_proxy, job_type) do
    case job_type do
      :debug_job -> forked_pr?(repo_proxy)
      _ -> forked_pr?(repo_proxy)
    end
  end

  defp assume_role_duration_seconds(:debug_job), do: 4_200
  defp assume_role_duration_seconds(_job_type), do: 87_300

  defp blank?(value), do: value in [nil, "", " "]

  defp forked_pr?(_repo = %{pr_slug: ""}), do: false
  defp forked_pr?(nil), do: false

  defp forked_pr?(repo) do
    [pr_repo | _rest] = repo.pr_slug |> String.split("/")
    [base_repo | _rest] = repo.repo_slug |> String.split("/")
    pr_repo != base_repo
  end
end
