# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Models.Job do
  require Logger

  alias InternalApi.ServerFarm.Job.{
    CanAttachRequest,
    CanDebugRequest,
    DescribeRequest,
    StopRequest
  }

  alias InternalApi.Loghub2.GenerateTokenRequest
  alias InternalApi.Loghub2.Loghub2.Stub, as: Loghub2Stub
  alias InternalApi.Loghub2.TokenType
  alias InternalApi.ServerFarm.Job.Job.{Result, State}
  alias InternalApi.ServerFarm.Job.JobService.Stub

  alias Front.Clients
  alias InternalApi.Velocity.ListJobSummariesRequest

  defstruct [
    :id,
    :name,
    :state,
    :project_id,
    :ppl_id,
    :failure_reason,
    :timeline,
    :self_hosted,
    :summary,
    :machine_type,
    :agent_name,
    :is_debug_job
  ]

  def find(id, tracing_headers \\ nil) do
    with {:ok, channel} <- GRPC.Stub.connect(internal_endpoint()),
         request <- DescribeRequest.new(job_id: id),
         {:ok, response} <-
           Stub.describe(channel, request, metadata: tracing_headers, timeout: 30_000) do
      if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        construct(response.job)
      else
        nil
      end
    else
      e ->
        Logger.info("describing job failed: #{id}, #{inspect(e)}")
        {:error, :grpc_req_failed}
    end
  end

  def generate_token(id, duration \\ 3_600, tracing_headers \\ nil) do
    with {:ok, channel} <- GRPC.Stub.connect(loghub2_endpoint()),
         request <-
           GenerateTokenRequest.new(job_id: id, type: TokenType.value(:PULL), duration: duration),
         {:ok, response} <-
           Loghub2Stub.generate_token(channel, request, metadata: tracing_headers, timeout: 30_000) do
      response.token
    else
      e ->
        Logger.info("Generating token failed: #{id}, #{inspect(e)}")
        ""
    end
  end

  def stop(job_id, user_id) do
    Watchman.benchmark("jobs.stop_request.duration", fn ->
      {:ok, channel} = GRPC.Stub.connect(internal_endpoint())

      request = StopRequest.new(job_id: job_id, requester_id: user_id)

      {:ok, _response} = Stub.stop(channel, request, timeout: 30_000)
    end)
  end

  def can_debug?(job_id, user_id) do
    Watchman.benchmark("jobs.can_debug.duration", fn ->
      {:ok, channel} = GRPC.Stub.connect(internal_endpoint())

      request = CanDebugRequest.new(job_id: job_id, user_id: user_id)

      case Stub.can_debug(channel, request, timeout: 30_000) do
        {:ok, %{allowed: allowed, message: message}} ->
          {:ok, allowed, message}

        e ->
          Logger.info("CanDebug Request failed: #{job_id}, #{inspect(e)}")
          {:error, false, ""}
      end
    end)
  end

  def can_attach?(job_id, user_id) do
    Watchman.benchmark("jobs.can_attach.duration", fn ->
      {:ok, channel} = GRPC.Stub.connect(internal_endpoint())

      request = CanAttachRequest.new(job_id: job_id, user_id: user_id)

      case Stub.can_attach(channel, request, timeout: 30_000) do
        {:ok, %{allowed: allowed, message: message}} ->
          {:ok, allowed, message}

        e ->
          Logger.info("CanAttach Request failed: #{job_id}, #{inspect(e)}")
          {:error, false, ""}
      end
    end)
  end

  defp construct(raw) do
    %__MODULE__{
      id: raw.id,
      name: raw.name,
      state: state(raw),
      project_id: raw.project_id,
      ppl_id: raw.ppl_id,
      failure_reason: raw.failure_reason,
      timeline: %{
        created_at: seconds(raw.timeline.created_at),
        started_at: seconds(raw.timeline.started_at),
        finished_at: seconds(raw.timeline.finished_at)
      },
      self_hosted: raw.self_hosted,
      machine_type: raw.machine_type,
      agent_name: raw.agent_name,
      is_debug_job: raw.is_debug_job
    }
    |> preload_summary()
  end

  def preload_summary(job) do
    ListJobSummariesRequest.new(job_ids: [job.id])
    |> Clients.Velocity.list_job_summaries()
    |> case do
      {:ok, %{job_summaries: [job_summary]}} -> job_summary
      _ -> nil
    end
    |> then(fn
      nil ->
        job

      summary ->
        summary
        |> Front.Models.TestSummary.load()
        |> then(&Map.put(job, :summary, &1))
    end)
  rescue
    e ->
      Logger.error("""
      Unexpected response #{inspect(e)} when receiving response from list_job_summary
      """)

      job
  end

  defp seconds(nil), do: nil
  defp seconds(time), do: time.seconds

  defp state(raw) do
    cond do
      State.key(raw.state) == :STARTED ->
        "running"

      State.key(raw.state) == :FINISHED and Result.key(raw.result) == :PASSED ->
        "passed"

      State.key(raw.state) == :FINISHED and Result.key(raw.result) == :FAILED ->
        "failed"

      State.key(raw.state) == :FINISHED and Result.key(raw.result) == :STOPPED ->
        "stopped"

      true ->
        "pending"
    end
  end

  defp internal_endpoint do
    Application.fetch_env!(:front, :job_api_grpc_endpoint)
  end

  defp loghub2_endpoint do
    Application.fetch_env!(:front, :loghub2_api_grpc_endpoint)
  end
end
