defmodule Zebra.Workers.JobRequestFactory.Repository do
  require Logger
  alias Zebra.Workers.JobRequestFactory.JobRequest

  def find(repository_id) do
    Watchman.benchmark("zebra.external.repository_hub.describe", fn ->
      alias InternalApi.Repository.DescribeRequest, as: Request
      alias InternalApi.Repository.RepositoryService.Stub

      req = Request.new(repository_id: repository_id, include_private_ssh_key: true)

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :repository_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, res} <- Stub.describe(channel, req, timeout: 30_000) do
        {:ok, serialize(res.repository), res.private_ssh_key}
      else
        {:error, error} ->
          Logger.info("Failed to fetch info for Repository##{repository_id}, #{inspect(error)}")

          if error.status == GRPC.Status.not_found() do
            {:stop_job_processing, "Repository '#{repository_id}' not found"}
          else
            {:error, :communication_error}
          end
      end
    end)
  end

  defp serialize(repository) do
    %{
      name: repository.name,
      url: repository.url,
      provider: repository.provider,
      default_branch: "master"
    }
  end

  def files(nil), do: {:ok, []}

  def files(private_git_key) do
    {:ok,
     [
       JobRequest.file(".ssh/id_rsa", private_git_key, "0600")
     ]}
  end

  def env_vars(repository, repo_proxy, job_type) do
    alias Zebra.Workers.JobRequestFactory.Repository

    case {job_type, repo_proxy} do
      {:pipeline_job, _} -> Repository.Job.env_vars(repository, repo_proxy)
      {:debug_job, nil} -> Repository.Project.env_vars(repository)
      {:debug_job, _} -> Repository.Job.env_vars(repository, repo_proxy)
      {:project_debug_job, _} -> Repository.Project.env_vars(repository)
    end
  end

  defmodule Project do
    def env_vars(repository) do
      {:ok,
       [
         JobRequest.env_var("SEMAPHORE_GIT_PROVIDER", repository.provider),
         JobRequest.env_var("SEMAPHORE_GIT_URL", repository.url),
         JobRequest.env_var("SEMAPHORE_GIT_REPO_NAME", repository.name),
         JobRequest.env_var("SEMAPHORE_GIT_DIR", repository.name),
         JobRequest.env_var("SEMAPHORE_GIT_BRANCH", repository.default_branch),
         JobRequest.env_var("SEMAPHORE_GIT_WORKING_BRANCH", repository.default_branch),
         JobRequest.env_var("SEMAPHORE_GIT_SHA", "HEAD")
       ]}
    end
  end

  defmodule Job do
    def env_vars(repository, repo_proxy) do
      {:ok, common(repository, repo_proxy) ++ reference_specific(repo_proxy)}
    end

    defp common(repository, repo_proxy) do
      [
        JobRequest.env_var("SEMAPHORE_GIT_PROVIDER", repository.provider),
        JobRequest.env_var("SEMAPHORE_GIT_URL", repository.url),
        JobRequest.env_var("SEMAPHORE_GIT_REPO_NAME", repository.name),
        JobRequest.env_var("SEMAPHORE_GIT_DIR", repository.name),
        JobRequest.env_var("SEMAPHORE_GIT_SHA", repo_proxy.head_commit_sha),
        JobRequest.env_var("SEMAPHORE_GIT_REPO_SLUG", repo_proxy.repo_slug),
        JobRequest.env_var("SEMAPHORE_GIT_REF", repo_proxy.git_ref),
        JobRequest.env_var("SEMAPHORE_GIT_COMMIT_RANGE", repo_proxy.commit_range)
      ]
    end

    def reference_specific(repo_proxy) do
      case InternalApi.RepoProxy.Hook.Type.key(repo_proxy.git_ref_type) do
        :BRANCH -> branch(repo_proxy)
        :TAG -> tag(repo_proxy)
        :PR -> pr(repo_proxy)
      end
    end

    defp branch(repo_proxy) do
      [
        JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "branch"),
        JobRequest.env_var("SEMAPHORE_GIT_BRANCH", repo_proxy.branch_name),
        JobRequest.env_var("SEMAPHORE_GIT_WORKING_BRANCH", repo_proxy.branch_name)
      ]
    end

    defp tag(repo_proxy) do
      [
        JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "tag"),
        JobRequest.env_var("SEMAPHORE_GIT_BRANCH", repo_proxy.git_ref),
        JobRequest.env_var("SEMAPHORE_GIT_TAG_NAME", repo_proxy.tag_name)
      ]
    end

    defp pr(repo_proxy) do
      [
        JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "pull-request"),
        JobRequest.env_var("SEMAPHORE_GIT_BRANCH", repo_proxy.branch_name),
        JobRequest.env_var("SEMAPHORE_GIT_PR_SLUG", repo_proxy.pr_slug),
        JobRequest.env_var("SEMAPHORE_GIT_PR_SHA", repo_proxy.pr_sha),
        JobRequest.env_var("SEMAPHORE_GIT_PR_NUMBER", repo_proxy.pr_number),
        JobRequest.env_var("SEMAPHORE_GIT_PR_NAME", repo_proxy.pr_name),
        JobRequest.env_var("SEMAPHORE_GIT_PR_BRANCH", repo_proxy.pr_branch_name),
        JobRequest.env_var("SEMAPHORE_GIT_WORKING_BRANCH", repo_proxy.pr_branch_name)
      ]
    end
  end
end
