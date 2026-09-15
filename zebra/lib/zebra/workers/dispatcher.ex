defmodule Zebra.Workers.Dispatcher do
  require Logger

  alias Zebra.Models.Job

  alias Zebra.Workers.Agent.HostedAgent
  alias Zebra.Workers.Agent.SelfHostedAgent

  require Logger

  def init do
    %Zebra.Workers.DbWorker{
      schema: Zebra.Models.Job,
      state_field: :aasm_state,
      state_value: Zebra.Models.Job.state_scheduled(),
      machine_type_field: :machine_type,
      machine_os_image_field: :machine_os_image,
      machine_type_environment: machine_type_environment(),
      order_by: :scheduled_at,
      order_direction: :asc,
      metric_name: "dispatcher",
      naptime: 1000,
      records_per_tick: 100,
      isolate_machine_types: isolate_machine_types(),
      processor: &process/1
    }
  end

  def machine_type_environment do
    cond do
      System.get_env("DISPATCH_SELF_HOSTED_ONLY") == "true" ->
        :self_hosted

      System.get_env("DISPATCH_CLOUD_ONLY") == "true" ->
        :cloud

      true ->
        :all
    end
  end

  def isolate_machine_types, do: System.get_env("DISPATCH_SELF_HOSTED_ONLY") != "true"

  def start_link do
    init() |> Zebra.Workers.DbWorker.start_link()
  end

  def process(job) do
    if Zebra.Models.Job.self_hosted?(job.machine_type) do
      dispatch_self_hosted_job(job)
    else
      dispatch_cloud_job(job)
    end
  end

  def dispatch_cloud_job(job) do
    with {:ok, agent} <- HostedAgent.occupy(job),
         host <- agent.ip_address,
         port <- agent.ctrl_port,
         token <- agent.auth_token,
         payload <- Poison.encode!(job.request),
         :ok <- HostedAgent.send(host, port, token, "/jobs", payload),
         {:ok, job} <- Job.start(job, agent, sanitize_request: true) do
      submit_metrics(job)

      :ok
    else
      # If chmura returns a NOT_FOUND response,
      # complaining about not having available agents for a machine type,
      # we stop sending occupy requests for this machine type until the next worker tick,
      # since the next requests will likely receive the same response.
      {:error, e = %GRPC.RPCError{status: 5}} ->
        Logger.error(
          "[#{job.id}] - #{inspect(e)} - no agent available for #{job.machine_type} - waiting until next tick"
        )

        {:halt, e}

      e ->
        Logger.error("[#{job.id}] #{inspect(e)}")
    end
  end

  def dispatch_self_hosted_job(job) do
    with {:ok, agent} <- SelfHostedAgent.occupy(job),
         {:ok, updated_job} <- update_job(job, agent) do
      # Latency is computed from started_at; on the waiting-for-agent path
      # started_at is nil so this is a no-op (no bogus/negative sample).
      submit_self_hosted_metrics(updated_job)

      :ok
    else
      e ->
        Logger.error("[#{job.id}] #{inspect(e)}")
    end
  end

  defp update_job(job, nil) do
    Logger.info("[#{job.id}] Sending job to waiting state")
    Job.wait_for_agent(job)
  end

  defp update_job(job, agent) do
    Logger.info("[#{job.id}] Sending job to started state")
    Job.start(job, agent)
  end

  def submit_metrics(job) do
    submit_dispatching_metrics("job.dispatching.duration", job)
  end

  # Self-hosted latency goes to a distinct metric name so it never mixes into the
  # untagged, cloud-only `job.dispatching.duration` timing series (which existing
  # dashboards read as-is). The histogram is already tagged by machine_type, so
  # cloud and self-hosted stay separable there.
  def submit_self_hosted_metrics(job) do
    submit_dispatching_metrics("job.dispatching.self_hosted.duration", job)
  end

  defp submit_dispatching_metrics(duration_metric, job) do
    case Zebra.Time.datetime_diff_in_ms(job.started_at, job.scheduled_at) do
      {:ok, ms} ->
        Watchman.submit(duration_metric, ms, :timing)

        tags = [
          job.organization_id,
          "#{job.machine_type}-#{job.machine_os_image}",
          duration_bucket(ms / 1000)
        ]

        Watchman.increment({"job.dispatching.histogram", tags})

      _ ->
        nil
    end
  end

  def duration_bucket(sec) when sec < 3, do: "from_0s_to_3s"
  def duration_bucket(sec) when sec >= 3 and sec < 10, do: "from_0s_to_3s"
  def duration_bucket(sec) when sec >= 10 and sec < 30, do: "from_10s_to_30s"
  def duration_bucket(sec) when sec >= 30 and sec < 60, do: "from_30s_to_60s"
  def duration_bucket(sec) when sec >= 60 and sec < 180, do: "from_60s_to_180s"
  def duration_bucket(sec) when sec >= 180 and sec < 600, do: "from_180s_to_600s"
  def duration_bucket(sec) when sec >= 600, do: "from_600s_to_inf"
end
