defmodule Zebra.Workers.JobFinishedCallbackWorker do
  use Tackle.Consumer,
    url: Application.get_env(:zebra, :amqp_url),
    exchange: "job_callbacks",
    routing_key: "finished",
    service: "zebra.callbacks",
    retry_limit: 3000,
    retry_delay: 10

  alias Zebra.Models.Job

  def handle_message(raw_message) do
    Watchman.benchmark("finished_callback.process.duration", fn ->
      message = Poison.decode!(raw_message)
      job_id = message["job_hash_id"]
      result = extract_result(message)

      Zebra.LegacyRepo.transaction(fn ->
        log(job_id, "Looking up job.")
        {:ok, job} = Job.find(job_id)
        log(job_id, "Job found.")

        log(job_id, "Transitioning from #{job.aasm_state} -> finished with '#{result}' result.")

        if Job.finished?(job) do
          log(job_id, "Job already finished")
        else
          {:ok, _} = Job.finish(job, result)
          log(job_id, "Job finished")
        end
      end)
    end)
  end

  def extract_result(message) do
    result = Poison.decode!(message["payload"])["result"]

    # handle broken payloads
    if result == nil do
      "failed"
    else
      result
    end
  end

  def log(job_id, message) do
    Logger.info("[JOB FINISHED CALLBACK_WORKER][job_id: #{job_id}] #{message}")
  end
end
