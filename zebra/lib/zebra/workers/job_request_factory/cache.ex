defmodule Zebra.Workers.JobRequestFactory.Cache do
  require Logger

  alias InternalApi.Cache.DescribeRequest, as: Request
  alias InternalApi.Cache.CacheService.Stub

  alias InternalApi.Secrethub.GenerateCacheOpenIDConnectTokenRequest, as: CacheTokenRequest
  alias InternalApi.Secrethub.SecretService.Stub, as: SecrethubStub

  alias Zebra.Workers.JobRequestFactory.JobRequest
  alias Zebra.Workers.JobRequestFactory.Machine

  # Cache OIDC token TTL. The token is injected once before the job starts and
  # cannot be regenerated from the job runtime; the job-side cache runtime uses
  # it to repeatedly exchange for short-lived STS credentials. It must therefore
  # outlive the whole job. Regular jobs run up to 24h, debug jobs up to 1h.
  # Secrethub clamps these to its allowed bounds.
  @regular_job_token_ttl_seconds 87_300
  @debug_job_token_ttl_seconds 4_200

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

    {:ok, maybe_add_parallel_archive(vars, organization_id)}
  end

  # Ceph reuses the cache-cli `ceph` backend (S3-compatible storage behind a
  # pull-through cache). Instead of injecting temporary STS credentials, Zebra
  # injects a cache-scoped OIDC token plus the selected role ARN; the job-side
  # cache runtime exchanges the token for short-lived S3 credentials via
  # AssumeRoleWithWebIdentity and refreshes them as needed.
  defp ceph_env_vars(job, cache, organization_id, repo_proxy, job_type) do
    read_only? = read_only_cache_access?(repo_proxy, job_type)
    role_arn = if read_only?, do: cache.ro_role_arn, else: cache.rw_role_arn
    cache_access = if read_only?, do: "read_only", else: "read_write"

    with false <- blank?(role_arn),
         false <- blank?(cache.bucket),
         {:ok, s3_url} <- ceph_cache_s3_url(),
         {:ok, token} <- generate_cache_oidc_token(job, organization_id, cache_access, job_type) do
      vars = [
        JobRequest.env_var("SEMAPHORE_CACHE_BACKEND", "ceph"),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_URL", s3_url),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_BUCKET", cache.bucket),
        JobRequest.env_var("SEMAPHORE_CACHE_ROLE_ARN", role_arn),
        JobRequest.env_var("SEMAPHORE_CACHE_OIDC_TOKEN", token)
      ]

      {:ok, maybe_add_parallel_archive(vars, organization_id)}
    else
      true ->
        {:ok, []}

      {:error, reason} ->
        Watchman.increment("external.cachehub.ceph_oidc.failed")

        # Never log the token. role_arn/cache_id are safe to log.
        Logger.error(
          "Failed to configure Ceph cache for cache_id=#{cache.id} role_arn=#{role_arn} reason=#{inspect(reason)}"
        )

        {:ok, []}
    end
  end

  defp generate_cache_oidc_token(job, organization_id, cache_access, job_type) do
    Watchman.benchmark("zebra.external.secrethub.generate_cache_oidc_token", fn ->
      req =
        CacheTokenRequest.new(
          organization_id: organization_id,
          project_id: job.project_id,
          job_id: job.id,
          job_type: to_string(job_type),
          cache_access: cache_access,
          expires_in: token_expires_in(job_type)
        )

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :secrethub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <-
             SecrethubStub.generate_cache_open_id_connect_token(channel, req, timeout: 30_000) do
        {:ok, response.token}
      else
        e -> {:error, {:secrethub_error, e}}
      end
    end)
  end

  defp maybe_add_parallel_archive(vars, organization_id) do
    if FeatureProvider.feature_enabled?(:cache_cli_parallel_archive_method,
         param: organization_id
       ) do
      vars ++ [JobRequest.env_var("SEMAPHORE_CACHE_ARCHIVE_METHOD", "native-parallel")]
    else
      vars
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

  defp ceph_cache_s3_url do
    case Application.fetch_env(:zebra, :ceph_cache_s3_url) do
      {:ok, url} when is_binary(url) and url != "" ->
        {:ok, String.trim_trailing(url, "/")}

      _ ->
        {:error, :missing_ceph_cache_s3_url}
    end
  end

  defp token_expires_in(:debug_job), do: @debug_job_token_ttl_seconds
  defp token_expires_in(:project_debug_job), do: @debug_job_token_ttl_seconds
  defp token_expires_in(_job_type), do: @regular_job_token_ttl_seconds

  # Forked pull request jobs (and debug jobs spawned from them, since repo_proxy
  # is resolved from the original job) get read-only cache access; all other
  # jobs get read-write.
  defp read_only_cache_access?(repo_proxy, _job_type), do: forked_pr?(repo_proxy)

  defp blank?(value), do: value in [nil, "", " "]

  defp forked_pr?(_repo = %{pr_slug: ""}), do: false
  defp forked_pr?(nil), do: false

  defp forked_pr?(repo) do
    [pr_repo | _rest] = repo.pr_slug |> String.split("/")
    [base_repo | _rest] = repo.repo_slug |> String.split("/")
    pr_repo != base_repo
  end
end
