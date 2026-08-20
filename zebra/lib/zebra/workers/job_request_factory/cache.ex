defmodule Zebra.Workers.JobRequestFactory.Cache do
  require Logger

  alias InternalApi.Cache.DescribeRequest, as: Request
  alias InternalApi.Cache.CacheService.Stub

  alias InternalApi.Secrethub.GenerateOpenIDConnectTokenRequest, as: TokenRequest
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
    skipped(:no_cache_id)
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

  # Always disconnect the gRPC channel once the describe RPC returns, whether it
  # succeeds or fails. Leaving the channel open leaks connections and eventually
  # exhausts memory under load.
  defp grpc_describe(channel, req),
    do: Stub.describe(channel, req, timeout: 30_000),
    after: GRPC.Stub.disconnect(channel)

  # On an OK describe, hand the cache to normalize_described_cache so that CEPH
  # caches (which legitimately carry a blank credential) are accepted instead of
  # being discarded as a blank-credential failure. Non-OK responses keep main's
  # explicit warning + tagged failure metric.
  defp handle_describe_response(response, cache_id) do
    ok_code = InternalApi.ResponseStatus.Code.value(:OK)

    cond do
      response.status.code != ok_code ->
        Logger.warning(
          "Cachehub describe returned non-OK status. cache_id=#{cache_id} status_code=#{inspect(response.status.code)}"
        )

        failed(:non_ok_response)
        {:ok, nil}

      true ->
        normalize_described_cache(response.cache, cache_id)
    end
  end

  defp failed(reason) do
    Watchman.increment({"external.cachehub.describe.failed", [to_string(reason)]})
  end

  defp skipped(reason) do
    Watchman.increment({"external.cachehub.describe.skipped", [to_string(reason)]})
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

  def env_vars(job, cache, organization, repo_proxy, job_type) do
    case cache_backend(cache) do
      :ceph ->
        ceph_env_vars(job, cache, organization, repo_proxy, job_type)

      :sftp ->
        sftp_env_vars(job, cache, organization.org_id)
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
  defp ceph_env_vars(job, cache, organization, repo_proxy, job_type) do
    read_only? = read_only_cache_access?(repo_proxy, job_type)
    role_arn = if read_only?, do: cache.ro_role_arn, else: cache.rw_role_arn
    cache_access = if read_only?, do: "read_only", else: "read_write"

    with false <- blank?(role_arn),
         false <- blank?(cache.bucket),
         {:ok, s3_url} <- ceph_cache_s3_url(),
         {:ok, token} <- generate_cache_oidc_token(job, organization, cache_access, job_type) do
      vars = [
        JobRequest.env_var("SEMAPHORE_CACHE_BACKEND", "ceph"),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_URL", s3_url),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_BUCKET", cache.bucket),
        JobRequest.env_var("SEMAPHORE_CACHE_ROLE_ARN", role_arn),
        JobRequest.env_var("SEMAPHORE_CACHE_OIDC_TOKEN", token)
      ]

      {:ok, maybe_add_parallel_archive(vars, organization.org_id)}
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

  # The cache token reuses the org's existing per-org OIDC issuer: Secrethub derives
  # `iss = https://<org_username>.<domain>` from `org_username` (identical to the
  # regular OIDC token), so we only customize `aud` (ceph-cache), `sub` (the
  # canonical per-project cache subject), and the TTL. The account-scoped Ceph OIDC
  # provider trusts exactly that issuer + aud + sub.
  defp generate_cache_oidc_token(job, organization, cache_access, job_type) do
    Watchman.benchmark("zebra.external.secrethub.generate_cache_oidc_token", fn ->
      req =
        TokenRequest.new(
          org_id: organization.org_id,
          org_username: organization.org_username,
          project_id: job.project_id,
          job_id: job.id,
          job_type: to_string(job_type),
          subject: cache_subject(organization.org_id, job.project_id, cache_access),
          audience: ["ceph-cache"],
          expires_in: token_expires_in(job_type)
        )

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :secrethub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- grpc_generate_oidc_token(channel, req) do
        {:ok, response.token}
      else
        e -> {:error, {:secrethub_error, e}}
      end
    end)
  end

  # Always disconnect the gRPC channel once the token RPC returns, whether it
  # succeeds or fails. Same channel-leak concern as grpc_describe/2.
  defp grpc_generate_oidc_token(channel, req),
    do: SecrethubStub.generate_open_id_connect_token(channel, req, timeout: 30_000),
    after: GRPC.Stub.disconnect(channel)

  # Canonical cache OIDC subject. MUST stay byte-for-byte identical to cachehub's
  # `Cachehub.Ceph.CacheClaims.subject/3`, which renders the project role trust
  # policy matching this `sub` via StringEquals. `access` is "read_only"/"read_write".
  defp cache_subject(org_id, project_id, access) do
    "org:#{org_id}:project:#{project_id}:access:#{access}"
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

  defp normalize_described_cache(nil, _cache_id), do: {:ok, nil}

  defp normalize_described_cache(cache, cache_id) do
    cond do
      ceph_cache_ready?(cache) ->
        {:ok, cache}

      sftp_cache_ready?(cache) ->
        {:ok, cache}

      cache_backend(cache) == :sftp ->
        # An sftp cache with a blank credential is unusable. Keep main's warning
        # + tagged failure metric for this genuinely-broken case.
        Logger.warning("Cachehub describe returned blank credential. cache_id=#{cache_id}")
        failed(:blank_credential)
        {:ok, nil}

      true ->
        {:ok, nil}
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

  defp blank?(nil), do: true
  defp blank?(credential), do: String.trim(credential) == ""

  # Public because Zebra.Workers.JobRequestFactory calls Cache.forked_pr?/1
  # cross-module (in its dropped-cache-vars logging guard).
  def forked_pr?(_repo = %{pr_slug: ""}), do: false
  def forked_pr?(nil), do: false

  def forked_pr?(repo) do
    [pr_repo | _rest] = repo.pr_slug |> String.split("/")
    [base_repo | _rest] = repo.repo_slug |> String.split("/")
    pr_repo != base_repo
  end
end
