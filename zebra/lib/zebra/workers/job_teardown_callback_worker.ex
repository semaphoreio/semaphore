defmodule Zebra.Workers.JobTeardownCallbackWorker do
  use Tackle.Consumer,
    url: Application.get_env(:zebra, :amqp_url),
    exchange: "job_callbacks",
    routing_key: "teardown_finished",
    service: "zebra.callbacks",
    retry_limit: 3000,
    retry_delay: 10

  alias Zebra.Models.Job

  def handle_message(raw_message) do
    Watchman.benchmark("teardown_callback.process.duration", fn ->
      message = Poison.decode!(raw_message)
      job_id = message["job_hash_id"]

      case Job.find(job_id) do
        {:ok, job} ->
          log(job_id, "Job found, releasing agent")

          :ok = Job.publish_teardown_finished_event(job)

          case release(job) do
            :ok -> :ok
            {:error, msg} -> raise msg
          end

        _ ->
          log(job_id, "Job not found")
      end
    end)
  end

  def release(job) do
    if Zebra.Models.Job.self_hosted?(job.machine_type) do
      Zebra.Workers.Agent.SelfHostedAgent.release(job)
    else
      Zebra.Workers.Agent.HostedAgent.release(job)
    end
  end

  def log(job_id, message) do
    Logger.info("[JOB TEARDOWN CALLBACK_WORKER][job_id: #{job_id}] #{message}")
  end
end
