defmodule Zebra.Workers.JobStartedCallbackWorker do
  use Tackle.Consumer,
    url: Application.get_env(:zebra, :amqp_url),
    exchange: "server_farm.job_state_exchange",
    routing_key: "job_started",
    service: "zebra.callbacks",
    retry_limit: 3000,
    retry_delay: 10

  alias Zebra.Models.Job

  def handle_message(raw_message) do
    Watchman.benchmark("started_callback.process.duration", fn ->
      message = InternalApi.ServerFarm.MQ.JobStateExchange.JobStarted.decode(raw_message)
      job_id = message.job_id

      Zebra.LegacyRepo.transaction(fn ->
        log(job_id, "Looking up job.")
        {:ok, job} = Job.find(job_id)

        log(job_id, "Transitioning from #{job.aasm_state} -> started.")

        cond do
          Job.started?(job) ->
            log(job_id, "Job already started")

          Job.finished?(job) ->
            log(job_id, "Job already finished")

          true ->
            {:ok, job} =
              Job.start(job, %{
                id: message.agent_id,
                name: message.agent_name,
                ip_address: "",
                ctrl_port: "",
                auth_token: "",
                ssh_port: ""
              })

            onprem_metrics(job)

            log(job_id, "Job started")
        end
      end)
    end)
  end

  def log(job_id, message) do
    Logger.info("[JOB STARTED CALLBACK WORKER][job_id: #{job_id}] #{message}")
  end

  defp onprem_metrics(job) do
    if Zebra.on_prem?() do
      case Zebra.Time.datetime_diff_in_ms(job.started_at, job.scheduled_at) do
        {:ok, ms} ->
          Watchman.increment(
            external:
              {"dispatching.histogram",
               [
                 agent: "#{job.machine_type}",
                 duration_bucket: duration_bucket(ms / 1000)
               ]}
          )

        _ ->
          nil
      end
    end
  end

  defp duration_bucket(sec) when sec < 3, do: "from_0s_to_3s"
  defp duration_bucket(sec) when sec >= 3 and sec < 10, do: "from_3s_to_10s"
  defp duration_bucket(sec) when sec >= 10 and sec < 30, do: "from_10s_to_30s"
  defp duration_bucket(sec) when sec >= 30 and sec < 60, do: "from_30s_to_60s"
  defp duration_bucket(sec) when sec >= 60 and sec < 180, do: "from_60s_to_180s"
  defp duration_bucket(sec) when sec >= 180 and sec < 600, do: "from_180s_to_600s"
  defp duration_bucket(sec) when sec >= 600, do: "from_600s_to_inf"
end
