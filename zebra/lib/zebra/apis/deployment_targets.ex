defmodule Zebra.Apis.DeploymentTargets do
  alias InternalApi.Gofer.DeploymentTargets, as: API
  alias Zebra.Models.Job
  alias Zebra.Workers.JobRequestFactory.RepoProxy
  require Logger

  @endpoint_name :dt_api_endpoint
  @timeout 30_000

  def can_run?(%{deployment_target_id: nil}, _user_id),
    do: {:ok, true}

  def can_run?(%{deployment_target_id: ""}, _user_id),
    do: {:ok, true}

  def can_run?(job, user_id) do
    job_type = Job.detect_type(job)
    target_id = job.deployment_target_id

    with {:ok, hook_id} <- RepoProxy.extract_hook_id(job, job_type),
         find_repo_proxy <- Task.async(fn -> RepoProxy.find(hook_id) end),
         {:ok, repo_proxy} <- Task.await(find_repo_proxy) do
      git_ref_type = InternalApi.RepoProxy.Hook.Type.key(repo_proxy.git_ref_type)
      git_ref_label = git_ref_label(git_ref_type, repo_proxy)

      case verify_dt_access(target_id, user_id, git_ref_type, git_ref_label) do
        {:ok, :ACCESS_GRANTED} ->
          {:ok, true}

        {:ok, denial_reason} ->
          message = dt_denial_message(target_id, denial_reason)
          {:error, :permission_denied, message}

        {:error, message} ->
          {:error, :internal, message}
      end
    end
  end

  defp dt_denial_message(target_id, denial_reason) do
    "You are not allowed to access Deployment Target[#{target_id}]: #{denial_reason}"
  end

  def verify_dt_access(target_id, user_id, git_ref_type, git_ref_label) do
    Watchman.benchmark("zebra.external.deployment_targets.verify", fn ->
      request = form_request(target_id, user_id, git_ref_type, git_ref_label)

      with {:ok, endpoint} <- Application.fetch_env(:zebra, @endpoint_name),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- grpc_send(channel, request) do
        {:ok, API.VerifyResponse.Status.key(response.status)}
      else
        e ->
          Logger.warn("Verifying access to deployment target #{target_id} failed, #{inspect(e)}")
          {:error, "Unable to verify access to deployment target #{target_id}"}
      end
    end)
  end

  defp grpc_send(channel, request),
    do: API.DeploymentTargets.Stub.verify(channel, request, timeout: @timeout),
    after: GRPC.Stub.disconnect(channel)

  defp form_request(target_id, user_id, git_ref_type, git_ref_label) do
    alias API.VerifyRequest.GitRefType
    git_ref_type = GitRefType.value(git_ref_type)

    API.VerifyRequest.new(
      target_id: target_id,
      triggerer: user_id,
      git_ref_type: git_ref_type,
      git_ref_label: git_ref_label
    )
  end

  defp git_ref_label(:BRANCH, %{branch_name: branch_name}), do: branch_name
  defp git_ref_label(:TAG, %{tag_name: tag_name}), do: tag_name
  defp git_ref_label(:PR, %{pr_number: pr_number}), do: pr_number
end
