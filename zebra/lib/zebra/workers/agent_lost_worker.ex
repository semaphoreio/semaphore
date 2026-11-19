defmodule Zebra.Workers.AgentLostWorker do
  @moduledoc """
  Fails the job of a hosted agent whose machine is gone.

  The secondary agent provider publishes AgentLost when the machine under an
  occupied agent is taken back or terminated. That job can never report back,
  so without this it would run until its execution time limit. The job is
  finished as failed with a reason the job page shows. It is not retried.

  The provider has already released the agent, so nothing is released here.
  Delivery is at least once: a job that is already finished, that runs on a
  different agent, or that is not served by the secondary provider is left as
  it is.
  """

  use Tackle.Consumer,
    url: Application.get_env(:zebra, :amqp_url),
    exchange: "hosted_agent_events",
    routing_key: "agent_lost",
    service: "zebra.hosted_agent_events",
    retry_limit: 30,
    retry_delay: 10

  require Logger
  alias InternalApi.HostedAgentEvents.AgentLost
  alias InternalApi.HostedAgentEvents.AgentLost.Reason
  alias Zebra.LegacyRepo, as: Repo
  alias Zebra.Models.Job
  alias Zebra.Workers.Agent.HostedAgent

  def handle_message(raw_message) do
    Watchman.benchmark("agent_lost.process.duration", fn ->
      message = AgentLost.decode(raw_message)
      message = %{message | reason: reason_key(message.reason)}
      reason = message.reason |> Atom.to_string() |> String.downcase()

      log(message.job_id, "Agent '#{message.agent_id}' lost: #{reason}")

      {:ok, outcome} = Repo.transaction(fn -> process(message) end)

      Watchman.increment({"agent_lost.processed", [reason, Atom.to_string(outcome)]})

      :ok
    end)
  end

  defp process(message) do
    case load_job_with_lock(message.job_id) do
      nil ->
        log(message.job_id, "Job not found, dropping message.")
        :not_found

      job ->
        fail(job, message)
    end
  end

  defp fail(job, message) do
    cond do
      Job.finished?(job) ->
        log(job.id, "Job already finished.")
        :already_finished

      not Job.hosted?(job.machine_type) ->
        log(job.id, "Job is not on a hosted agent, ignoring.")
        :ignored

      job.agent_id not in [nil, "", message.agent_id] ->
        log(job.id, "Job runs on agent '#{job.agent_id}', not '#{message.agent_id}', ignoring.")
        :ignored

      has_agent?(job) and job.agent_provider != HostedAgent.secondary_provider() ->
        log(job.id, "Job's agent is not from the secondary provider, ignoring.")
        :ignored

      true ->
        finish(job, message)
    end
  end

  # A job whose agent was occupied but not recorded yet has no agent id and no
  # provider. It can only be named by the provider that gave it the agent.
  defp has_agent?(job), do: job.agent_id not in [nil, ""]

  defp finish(job, message) do
    failure_reason = failure_reason(message.reason)

    case Job.finish(job, Job.result_failed(), %{failure_reason: failure_reason}) do
      {:ok, _} ->
        log(job.id, "Job failed: #{failure_reason}")
        :failed

      {:error, :invalid_transition} ->
        log(job.id, "Job is in '#{job.aasm_state}', can not finish it.")
        :ignored

      {:error, e} ->
        raise "could not fail job #{job.id}: #{inspect(e)}"
    end
  end

  def failure_reason(:PREEMPTED),
    do: "The machine running this job was stopped by the infrastructure provider."

  def failure_reason(:MACHINE_TERMINATED),
    do: "The machine running this job was terminated."

  def failure_reason(_), do: "The machine running this job was lost."

  # Enums decode to integers. A reason added later by the publisher is
  # treated as unspecified.
  defp reason_key(value) when is_integer(value) do
    Reason.key(value)
  rescue
    FunctionClauseError -> :REASON_UNSPECIFIED
  end

  defp reason_key(_), do: :REASON_UNSPECIFIED

  defp load_job_with_lock(job_id) do
    with {:ok, id} <- Ecto.UUID.cast(job_id),
         {:ok, job} <- Job.find_for_update(id) do
      job
    else
      _ -> nil
    end
  end

  defp log(job_id, message) do
    Logger.info("[AGENT LOST WORKER][job_id: #{job_id}] #{message}")
  end
end
