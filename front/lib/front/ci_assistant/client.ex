defmodule Front.CiAssistant.Client do
  @moduledoc """
  gRPC client for the CI Assistant gateway service.
  Used to trigger and monitor autonomous onboarding sessions.
  """

  require Logger

  def start_onboarding(org_id, user_id, project_id) do
    request =
      InternalApi.CiAssistant.StartOnboardingRequest.new(
        org_id: org_id,
        user_id: user_id,
        project_id: project_id
      )

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           InternalApi.CiAssistant.Gateway.Stub.start_onboarding(channel, request) do
      {:ok, response.session_key}
    else
      {:error, reason} ->
        Logger.error("CI Assistant StartOnboarding failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_onboarding_status(session_key) do
    request =
      InternalApi.CiAssistant.GetOnboardingStatusRequest.new(session_key: session_key)

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           InternalApi.CiAssistant.Gateway.Stub.get_onboarding_status(channel, request) do
      {:ok,
       %{
         status: response.status,
         yaml_content: response.yaml_content,
         commit_sha: response.commit_sha,
         branch: response.branch,
         error: response.error,
         tool_log: response.tool_log || []
       }}
    else
      {:error, reason} ->
        Logger.error("CI Assistant GetOnboardingStatus failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp connect do
    endpoint = Application.get_env(:front, :ci_assistant_grpc_endpoint, "localhost:50051")
    GRPC.Stub.connect(endpoint)
  end
end
