defmodule Zebra.Workers.JobRequestFactory.Cache do
  require Logger
  alias InternalApi.Cache.DescribeRequest, as: Request
  alias InternalApi.Cache.{GetS3CredentialsRequest, GetS3CredentialsResponse}
  alias InternalApi.Cache.CacheService.Stub

  alias Zebra.Workers.JobRequestFactory.JobRequest
  alias Zebra.Workers.JobRequestFactory.Machine

  #
  # If cache_id is nil, we skip injecting cache information,
  # If cache is not found, we skip injecting cache information,
  #
  # Overall, if cache system is down, we ignore every issue.
  #

  def find(cache_id, repo_proxy, org_id, job_type \\ :pipeline_job, project \\ nil)

  def find(nil, _repo_proxy, _org_id, _job_type, _project) do
    skipped(:no_cache_id)
    {:ok, nil}
  end

  def find(cache_id, repo_proxy, org_id, job_type, project) do
    Watchman.benchmark("external.cachehub.describe", fn ->
      req = Request.new(cache_id: cache_id)

      with false <- skip_cache?(repo_proxy, org_id, job_type, project),
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

  @doc """
  Temporary S3 credentials for the job's project prefix in the cache bucket.
  Like find/5, it never fails the job: without credentials, the job gets no cache.
  """
  def find_s3(job, project, repo_proxy, job_type, min_validity_seconds)

  def find_s3(_job, %{cache_id: nil}, _repo_proxy, _job_type, _min_validity_seconds) do
    skipped_s3(:no_cache_id)
    {:ok, nil}
  end

  def find_s3(job, project, repo_proxy, job_type, min_validity_seconds) do
    Watchman.benchmark("external.cachehub.get_s3_credentials", fn ->
      req =
        GetS3CredentialsRequest.new(
          project_id: job.project_id,
          min_validity_seconds: min_validity_seconds
        )

      with false <- skip_s3_cache?(repo_proxy, job.organization_id, job_type, project),
           {:ok, endpoint} <- Application.fetch_env(:zebra, :cachehub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- grpc_get_s3_credentials(channel, req) do
        handle_s3_credentials_response(response, job.project_id)
      else
        true ->
          skipped_s3(:forked_pr)
          {:ok, nil}

        e ->
          Logger.warning(
            "Failed to fetch S3 credentials from cachehub. project_id=#{job.project_id} error=#{inspect(e)}"
          )

          failed_s3(:grpc_error)
          {:ok, nil}
      end
    end)
  end

  defp grpc_get_s3_credentials(channel, req),
    do: Stub.get_s3_credentials(channel, req, timeout: 30_000),
    after: GRPC.Stub.disconnect(channel)

  defp handle_s3_credentials_response(response, project_id) do
    required = [
      response.bucket,
      response.region,
      response.access_key_id,
      response.secret_access_key,
      response.session_token
    ]

    cond do
      not ok?(response) ->
        Logger.warning(
          "Cachehub returned non-OK status for S3 credentials. project_id=#{project_id} status_code=#{inspect(status_code(response))}"
        )

        failed_s3(:non_ok_response)
        {:ok, nil}

      Enum.any?(required, &blank?/1) ->
        Logger.warning("Cachehub returned incomplete S3 credentials. project_id=#{project_id}")

        failed_s3(:incomplete_credentials)
        {:ok, nil}

      true ->
        {:ok, response}
    end
  end

  # Forked pull requests get no S3 credentials, whatever disable_forked_pr_cache says,
  # unless their approval enabled the cache. Debug jobs never take that approval.
  defp skip_s3_cache?(repo_proxy, _org_id, :debug_job, _project),
    do: forked_pr_without_approval_override?(repo_proxy)

  defp skip_s3_cache?(repo_proxy, org_id, _job_type, project),
    do: forked_pr?(repo_proxy, org_id, project)

  defp ok?(%{status: %{code: code}}), do: code == InternalApi.ResponseStatus.Code.value(:OK)
  defp ok?(_response), do: false

  defp status_code(%{status: %{code: code}}), do: code
  defp status_code(_response), do: nil

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

  defp failed_s3(reason) do
    Watchman.increment({"external.cachehub.get_s3_credentials.failed", [to_string(reason)]})
  end

  defp skipped_s3(reason) do
    Watchman.increment({"external.cachehub.get_s3_credentials.skipped", [to_string(reason)]})
  end

  def files(_, nil), do: {:ok, []}
  def files(_job, %GetS3CredentialsResponse{}), do: {:ok, []}

  def files(job, cache) do
    path = "#{Machine.home_path(job)}/.ssh/semaphore_cache_key"

    {:ok,
     [
       JobRequest.file(path, cache.credential, "0600")
     ]}
  end

  @doc """
  With S3 credentials, a job that sets any SEMAPHORE_CACHE_* variable itself
  gets none of these, so its own cache settings are never mixed with them.
  """
  def env_vars(job, cache, organization_id, job_env_var_names \\ [])

  def env_vars(_, nil, _, _), do: {:ok, []}

  def env_vars(_job, credentials = %GetS3CredentialsResponse{}, organization_id, names) do
    if Enum.any?(names, &cache_env_var?/1) do
      {:ok, []}
    else
      vars = [
        JobRequest.env_var("SEMAPHORE_CACHE_BACKEND", "s3"),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_BUCKET", credentials.bucket),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_REGION", credentials.region),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_KEY", credentials.access_key_id),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_SECRET", credentials.secret_access_key),
        JobRequest.env_var("SEMAPHORE_CACHE_S3_SESSION_TOKEN", credentials.session_token)
      ]

      {:ok, vars ++ archive_method_env_vars(organization_id)}
    end
  end

  def env_vars(job, cache, organization_id, _job_env_var_names) do
    path = "#{Machine.home_path(job)}/.ssh/semaphore_cache_key"
    user = String.replace(cache.id, "-", "")

    vars = [
      JobRequest.env_var("SSH_PRIVATE_KEY_PATH", path),
      JobRequest.env_var("SEMAPHORE_CACHE_BACKEND", "sftp"),
      JobRequest.env_var("SEMAPHORE_CACHE_PRIVATE_KEY_PATH", path),
      JobRequest.env_var("SEMAPHORE_CACHE_USERNAME", user),
      JobRequest.env_var("SEMAPHORE_CACHE_URL", cache.url)
    ]

    {:ok, vars ++ archive_method_env_vars(organization_id)}
  end

  defp archive_method_env_vars(organization_id) do
    if FeatureProvider.feature_enabled?(:cache_cli_parallel_archive_method,
         param: organization_id
       ) do
      [JobRequest.env_var("SEMAPHORE_CACHE_ARCHIVE_METHOD", "native-parallel")]
    else
      []
    end
  end

  defp cache_env_var?(name) when is_binary(name),
    do: String.starts_with?(String.upcase(name), "SEMAPHORE_CACHE_")

  defp cache_env_var?(_name), do: false

  def forked_pr?(repo, org_id \\ nil, project \\ nil)
  def forked_pr?(_repo = %{pr_slug: ""}, _org_id, _project), do: false
  def forked_pr?(nil, _org_id, _project), do: false

  def forked_pr?(repo, org_id, project) do
    if approval_enable_cache?(repo, org_id, project) do
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

  defp skip_cache?(repo_proxy, org_id, :debug_job, _project) do
    forked_pr_without_approval_override?(repo_proxy) and
      FeatureProvider.feature_enabled?(:disable_forked_pr_cache, param: org_id)
  end

  defp skip_cache?(repo_proxy, org_id, _job_type, project) do
    forked_pr?(repo_proxy, org_id, project) and
      FeatureProvider.feature_enabled?(:disable_forked_pr_cache, param: org_id)
  end

  defp approval_enable_cache?(nil, _org_id, _project), do: false
  defp approval_enable_cache?(_repo, nil, _project), do: false

  # Re-checked per job so reruns of an approved workflow lose the grant once
  # the project setting or the org feature is turned off.
  defp approval_enable_cache?(repo, org_id, project) do
    Map.get(repo, :approval_enable_cache, false) and
      project_allows_cache?(project) and
      FeatureProvider.feature_enabled?(:sem_approve_options, param: org_id)
  end

  defp project_allows_cache?(%{forked_pull_requests: %{} = settings}),
    do: Map.get(settings, :allow_sem_approve_enable_cache) == true

  defp project_allows_cache?(_project), do: false
end
