defmodule Zebra.Workers.JobRequestFactory do
  require Logger

  alias Zebra.Models.Job

  alias Zebra.Workers.JobRequestFactory.{
    Artifacthub,
    Cache,
    CallbackToken,
    JobRequest,
    Loghub2,
    Machine,
    OpenIDConnect,
    Organization,
    Project,
    RepoProxy,
    Repository,
    Secrets,
    Spec,
    ToolboxInstall
  }

  def init do
    %Zebra.Workers.DbWorker{
      schema: Zebra.Models.Job,
      state_field: :aasm_state,
      state_value: Zebra.Models.Job.state_pending(),
      metric_name: "job_request_factory",
      order_by: :created_at,
      order_direction: :asc,
      naptime: 1000,
      processor: &process/1
    }
  end

  def start_link do
    init() |> Zebra.Workers.DbWorker.start_link()
  end

  def process(job) do
    org_id = job.organization_id
    spec = Job.decode_spec(job.spec)
    job_type = Job.detect_type(job)

    find_project = Task.async(fn -> Project.find(job.project_id) end)
    find_org = Task.async(fn -> Organization.find(org_id) end)

    gen_rsa =
      Task.async(fn ->
        if Job.self_hosted?(job.machine_type), do: {:ok, nil}, else: {:ok, Zebra.RSA.generate()}
      end)

    generate_token =
      Task.async(fn ->
        if Job.self_hosted?(job.machine_type),
          do: Loghub2.generate_token(job.id),
          else: {:ok, nil}
      end)

    with :ok <- Machine.validate(org_id, job),
         {:ok, hook_id} <- RepoProxy.extract_hook_id(job, job_type),
         find_repo_proxy <- Task.async(fn -> RepoProxy.find(hook_id) end),
         {:ok, rsa} <- Task.await(gen_rsa),
         {:ok, project} <- Task.await(find_project),
         find_repository <- Task.async(fn -> Repository.find(project.repository_id) end),
         find_artifact_token <-
           Task.async(fn ->
             Artifacthub.generate_token(project.artifact_store_id, job.id, project.id, spec)
           end),
         {:ok, repo_proxy} <- Task.await(find_repo_proxy),
         find_cache <-
           Task.async(fn ->
             if Job.self_hosted?(job.machine_type),
               do: {:ok, nil},
               else: Cache.find(project.cache_id, repo_proxy)
           end),
         find_secrets <-
           Task.async(fn -> Secrets.load(org_id, job.id, spec, project, repo_proxy) end),
         {:ok, repository, private_git_key} <- Task.await(find_repository),
         {:ok, repo_files} <- Repository.files(private_git_key),
         {:ok, repo_env_vars} <- Repository.env_vars(repository, repo_proxy, job_type),
         {:ok, spec_env_vars} <- Spec.env_vars(spec),
         {:ok, spec_files} <- Spec.files(spec),
         {:ok, spec_commands} <- Spec.commands(spec),
         {:ok, epilogue} <- Spec.epilogue(spec),
         {:ok, organization} <- Task.await(find_org),
         {:ok, cache} <- Task.await(find_cache),
         {:ok, cache_files} <- Cache.files(job, cache),
         {:ok, cache_env_vars} <- Cache.env_vars(job, cache, org_id),
         {:ok, all_secrets} <- Task.await(find_secrets),
         {:ok, artifact_env_var} <- Task.await(find_artifact_token),
         {:ok, loghub2_token} <- Task.await(generate_token),
         {:ok, open_id_token_env_vars} <-
           OpenIDConnect.load(job, repo_env_vars, organization, project, job_type, spec_env_vars),
         {:ok, callback_token} <- CallbackToken.generate(job) do
      org_url = "https://#{organization.org_username}.#{Application.get_env(:zebra, :domain)}"

      env_vars =
        env_vars(job, job_type, project.name, org_url) ++
          artifact_env_var ++
          cache_env_vars ++
          ToolboxInstall.env_vars(job) ++
          open_id_token_env_vars ++
          repo_env_vars ++
          Enum.flat_map(all_secrets.job_secrets, & &1.env_vars) ++
          spec_env_vars

      files =
        cache_files ++
          repo_files ++
          Enum.flat_map(all_secrets.job_secrets, & &1.files) ++
          spec_files

      request =
        JobRequest.encode(
          spec.agent,
          JobRequest.ssh_public_keys(rsa),
          job,
          spec_commands,
          epilogue,
          env_vars,
          files,
          all_secrets,
          callback_token
        )

      request = JobRequest.append_logger(request, job, org_url, loghub2_token)

      Logger.info("Request constructured for #{job.id}, saving into DB")

      case Zebra.Models.Job.enqueue(job, request, rsa) do
        {:ok, job} ->
          submit_metrics(job)

          Logger.info("Processing finished #{job.id}, new state: #{job.aasm_state}")
          {:ok, job}

        e ->
          Logger.error("Failed to process job #{job.id}, #{inspect(e)}")
          e
      end
    else
      {:stop_job_processing, reason} ->
        Logger.error("Stopping job processing #{job.id}, reason: #{reason}")

        Job.force_finish(job, reason)

      e ->
        Logger.error("Error while processing #{job.id}, #{inspect(e)}")
        e
    end
  end

  def submit_metrics(job) do
    Zebra.Metrics.submit_datetime_diff(
      "job.initializing.duration",
      job.enqueued_at,
      job.created_at
    )
  end

  def env_vars(job, job_type, project_name, org_url) do
    common_vars = [
      JobRequest.env_var("TERM", "xterm"),
      JobRequest.env_var("CI", "true"),
      JobRequest.env_var("SEMAPHORE", "true"),
      JobRequest.env_var("SEMAPHORE_PROJECT_NAME", project_name),
      JobRequest.env_var("SEMAPHORE_PROJECT_ID", job.project_id),
      JobRequest.env_var("SEMAPHORE_JOB_NAME", job.name),
      JobRequest.env_var("SEMAPHORE_JOB_ID", job.id),
      JobRequest.env_var(
        "SEMAPHORE_JOB_CREATION_TIME",
        to_string(DateTime.to_unix(job.created_at, :second))
      ),
      JobRequest.env_var("SEMAPHORE_JOB_TYPE", to_string(job_type)),
      JobRequest.env_var("SEMAPHORE_AGENT_MACHINE_TYPE", job.machine_type),
      JobRequest.env_var("SEMAPHORE_AGENT_MACHINE_OS_IMAGE", job.machine_os_image),
      JobRequest.env_var(
        "SEMAPHORE_AGENT_MACHINE_ENVIRONMENT_TYPE",
        Machine.agent_environment(job)
      ),
      JobRequest.env_var("SEMAPHORE_ORGANIZATION_URL", org_url)
    ]

    if Job.hosted?(job.machine_type) do
      [
        JobRequest.env_var("PAGER", "cat"),
        JobRequest.env_var("DISPLAY", ":99")
      ] ++ common_vars
    else
      common_vars
    end
  end
end
