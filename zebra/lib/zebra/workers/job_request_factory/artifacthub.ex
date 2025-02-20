defmodule Zebra.Workers.JobRequestFactory.Artifacthub do
  require Logger
  alias InternalApi.Artifacthub.GenerateTokenRequest, as: Request
  alias InternalApi.Artifacthub.ArtifactService.Stub

  alias Zebra.Workers.JobRequestFactory.JobRequest

  @doc """
  If the artifact storage ID is nil or empty, we return {:stop_job_processing, error} to immediately stop the job.
  If the artifact API fails to describe the artifact storage ID, we return {:error, communication_error} and let it be retried.
  """

  def generate_token(nil, _, _, _), do: {:stop_job_processing, "Job is missing artifact storage"}
  def generate_token("", _, _, _), do: {:stop_job_processing, "Job is missing artifact storage"}

  def generate_token(artifact_id, job_id, project_id, spec) do
    Watchman.benchmark("external.artifacthub.generate", fn ->
      req =
        Request.new(
          artifact_id: artifact_id,
          job_id: job_id,
          workflow_id: workflow_id_from_spec(spec),
          project_id: project_id
        )

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :artifacthub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- Stub.generate_token(channel, req, timeout: 5_000) do
        {:ok,
         [
           JobRequest.env_var("SEMAPHORE_ARTIFACT_TOKEN", response.token)
         ]}
      else
        e ->
          Logger.error("Failed to generate artifact token for job #{job_id}: #{inspect(e)}")
          Watchman.increment("external.artifacthub.generate.failed")
          {:error, :communication_error}
      end
    end)
  end

  def workflow_id_from_spec(%{env_vars: vars}) do
    vars
    |> Enum.find(fn v -> v.name == "SEMAPHORE_WORKFLOW_ID" end)
    |> case do
      # We don't have a workflow ID for project debug jobs,
      # so we leave it empty in that scenario, meaning
      # that in project debug jobs, there is no restriction for
      # managing workflow-level artifacts.
      nil ->
        ""

      v ->
        v.value
    end
  end
end
