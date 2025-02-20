defmodule Zebra.Workers.Agent.SelfHostedAgent do
  require Logger

  alias InternalApi.SelfHosted.SelfHostedAgents.Stub

  alias InternalApi.SelfHosted.{
    ListRequest,
    OccupyAgentRequest,
    ReleaseAgentRequest,
    StopJobRequest
  }

  # 1 minute
  @cache_timeout 60 * 1000

  def load(org_id) do
    Zebra.Cache.fetch!("self-hosted-types-#{org_id}", @cache_timeout, fn ->
      result =
        Wormhole.capture(__MODULE__, :list, [org_id],
          timeout: 10_500,
          stacktrace: true,
          skip_log: true
        )

      case result do
        {:ok, {:ok, agent_types}} ->
          types = Enum.map(agent_types, fn t -> t.name end)
          {:commit, {:ok, types}}

        {:ok, error} ->
          {:ignore, error}

        error ->
          {:ignore, error}
      end
    end)
  end

  def list(org_id) do
    Watchman.benchmark("zebra.external.self-hosted.list", fn ->
      Logger.info("Listing agent types for #{org_id}")

      ch = channel()
      req = ListRequest.new(organization_id: org_id)

      case Stub.list(ch, req, timeout: 10_000) do
        {:ok, response} ->
          {:ok, response.agent_types}

        {:error, error} ->
          Logger.error("Error listing agent types for #{org_id}: #{inspect(error)}")
          {:error, error.message}
      end
    end)
  end

  def occupy(job) do
    Watchman.benchmark("zebra.external.self-hosted.occupy", fn ->
      Logger.info("Occupying agent for job: #{job.id} ...")

      ch = channel()
      req = occupy_request(job)

      case Stub.occupy_agent(ch, req, timeout: 30_000) do
        {:ok, response} ->
          {:ok, agent_response(response)}

        {:error, error} ->
          Logger.error(inspect(error))
          {:error, error.message}
      end
    end)
  end

  defp agent_response(response) do
    if blank?(response.agent_id) || blank?(response.agent_name) do
      # SHH no longer sends the agent information in this response.
      # It will store the occupation request and send a job_started event
      # for this job once an agent is available to run it.
      nil
    else
      # We still need this for backwards compatibility purposes.
      # The old version of SHH will still send agent information in this response.
      # Once we update SHH to send the agent information through the job_started callback, we can remove this clause.
      %{
        id: response.agent_id,
        name: response.agent_name,
        ip_address: "",
        ctrl_port: "",
        auth_token: "",
        ssh_port: ""
      }
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp occupy_request(job) do
    OccupyAgentRequest.new(
      job_id: job.id,
      organization_id: job.organization_id,
      agent_type: job.machine_type
    )
  end

  def release(job) do
    Watchman.benchmark("zebra.external.self-hosted.release", fn ->
      Logger.info("Releasing agent for job '#{job.id}' agent_id: '#{job.agent_id}'")

      ch = channel()
      req = release_request(job)

      case Stub.release_agent(ch, req, timeout: 30_000) do
        {:ok, _} ->
          :ok

        {:error, err} ->
          ids = "job_id:'#{job.id}' agent_id:'#{job.agent_id}'"
          Logger.error("Error while releasing self-hosted agent #{ids}, err: #{inspect(err)}")
          {:error, err.message}
      end
    end)
  end

  defp release_request(job) do
    ReleaseAgentRequest.new(
      organization_id: job.organization_id,
      agent_type: job.machine_type,
      job_id: job.id
    )
  end

  def stop(job) do
    Watchman.benchmark("zebra.external.self-hosted.stop", fn ->
      Logger.info("Stopping job: #{job.id} ...")

      ch = channel()
      req = stop_request(job)

      case Stub.stop_job(ch, req, timeout: 30_000) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.error(inspect(error))
          {:error, error.message}
      end
    end)
  end

  defp stop_request(job) do
    StopJobRequest.new(
      organization_id: job.organization_id,
      agent_type: job.machine_type,
      job_id: job.id
    )
  end

  defp channel do
    endpoint = Application.fetch_env!(:zebra, :self_hosted_agents_grpc_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)
    channel
  end
end
