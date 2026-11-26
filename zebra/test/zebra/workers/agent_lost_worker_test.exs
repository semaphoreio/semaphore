defmodule Zebra.Workers.AgentLostWorkerTest do
  use Zebra.DataCase

  alias InternalApi.HostedAgentEvents.AgentLost
  alias InternalApi.HostedAgentEvents.AgentLost.Reason
  alias Zebra.LegacyRepo, as: Repo
  alias Zebra.Models.Job
  alias Zebra.Workers.AgentLostWorker, as: W
  alias Zebra.Workers.JobFinishedCallbackWorker

  @agent_id Ecto.UUID.generate()

  @preempted "The machine running this job was stopped by the infrastructure provider."
  @terminated "The machine running this job was terminated."
  @lost "The machine running this job was lost."

  defp message(job_id, reason, agent_id \\ @agent_id) do
    AgentLost.new(
      agent_id: agent_id,
      job_id: job_id,
      reason: if(is_atom(reason), do: Reason.value(reason), else: reason),
      at: Google.Protobuf.Timestamp.new(seconds: 1),
      agent_type: "e1-standard-2"
    )
    |> AgentLost.encode()
  end

  defp started_job(params \\ %{}) do
    {:ok, job} =
      Support.Factories.Job.create(
        :started,
        Map.merge(%{agent_id: @agent_id, agent_provider: "secondary"}, params)
      )

    job
  end

  # Locks the job row in another connection, finishes the job there and keeps
  # the lock for a while before committing.
  defp finish_elsewhere(job_id, result, params) do
    parent = self()

    holder =
      Task.async(fn ->
        Repo.transaction(fn ->
          {:ok, job} = Job.find_for_update(job_id)
          send(parent, :locked)
          {:ok, _} = Job.finish(job, result, params)
          Process.sleep(500)
        end)
      end)

    assert_receive :locked, 5_000
    holder
  end

  describe ".handle_message" do
    test "a preempted machine fails the running job with its reason" do
      job = started_job()

      assert :ok = W.handle_message(message(job.id, :PREEMPTED))

      {:ok, job} = Job.find(job.id)
      assert Job.finished?(job)
      assert Job.failed?(job)
      refute is_nil(job.finished_at)
      assert job.failure_reason == @preempted
    end

    test "a terminated machine fails the running job with its reason" do
      job = started_job()

      assert :ok = W.handle_message(message(job.id, :MACHINE_TERMINATED))

      {:ok, job} = Job.find(job.id)
      assert Job.failed?(job)
      assert job.failure_reason == @terminated
    end

    test "a missing machine or an unknown reason fails the job as lost" do
      for reason <- [:MACHINE_MISSING, :REASON_UNSPECIFIED, 42] do
        job = started_job()

        assert :ok = W.handle_message(message(job.id, reason))

        {:ok, job} = Job.find(job.id)
        assert Job.failed?(job)
        assert job.failure_reason == @lost
      end
    end

    test "a job that got its agent but did not record it yet is failed" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)
      assert is_nil(job.agent_id)
      assert is_nil(job.agent_provider)

      assert :ok = W.handle_message(message(job.id, :MACHINE_TERMINATED))

      {:ok, job} = Job.find(job.id)
      assert Job.finished?(job)
      assert Job.failed?(job)
    end

    test "a redelivered message leaves the failed job as it is" do
      job = started_job()

      assert :ok = W.handle_message(message(job.id, :PREEMPTED))
      {:ok, failed} = Job.find(job.id)

      assert :ok = W.handle_message(message(job.id, :MACHINE_MISSING))
      {:ok, again} = Job.find(job.id)

      assert again.failure_reason == failed.failure_reason
      assert again.finished_at == failed.finished_at
    end

    test "a job that already finished keeps its result" do
      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          result: "passed",
          agent_id: @agent_id,
          agent_provider: "secondary"
        })

      assert :ok = W.handle_message(message(job.id, :PREEMPTED))

      {:ok, job} = Job.find(job.id)
      assert Job.passed?(job)
      assert is_nil(job.failure_reason)
    end

    test "a job on another agent is left running" do
      job = started_job()

      assert :ok = W.handle_message(message(job.id, :PREEMPTED, Ecto.UUID.generate()))

      {:ok, job} = Job.find(job.id)
      assert Job.started?(job)
      assert is_nil(job.result)
    end

    test "a job whose agent is from the default provider is left running" do
      for provider <- [nil, "", "other"] do
        job = started_job(%{agent_provider: provider})

        assert :ok = W.handle_message(message(job.id, :MACHINE_TERMINATED))

        {:ok, job} = Job.find(job.id)
        assert Job.started?(job)
        assert is_nil(job.result)
      end
    end

    test "a self-hosted job is left running" do
      job = started_job(%{machine_type: "s1-local"})

      assert :ok = W.handle_message(message(job.id, :MACHINE_TERMINATED))

      {:ok, job} = Job.find(job.id)
      assert Job.started?(job)
    end

    test "a message that still carries the removed field 5 is decoded" do
      job = started_job()
      legacy_field = "machine-1"

      raw =
        message(job.id, :MACHINE_TERMINATED) <>
          <<42, byte_size(legacy_field)>> <> legacy_field

      assert :ok = W.handle_message(raw)

      {:ok, job} = Job.find(job.id)
      assert Job.failed?(job)
      assert job.failure_reason == @terminated
    end

    test "an unknown or malformed job id is dropped" do
      assert :ok = W.handle_message(message(Ecto.UUID.generate(), :PREEMPTED))
      assert :ok = W.handle_message(message("not-a-uuid", :PREEMPTED))
      assert :ok = W.handle_message(message("", :PREEMPTED))
    end
  end

  describe "concurrent finishes" do
    test "a job that finishes while the loss is processed keeps its result" do
      job = started_job()

      holder = finish_elsewhere(job.id, "passed", %{})

      assert :ok = W.handle_message(message(job.id, :MACHINE_TERMINATED))
      assert {:ok, _} = Task.await(holder)

      {:ok, job} = Job.find(job.id)
      assert Job.passed?(job)
      assert is_nil(job.failure_reason)
    end

    test "a finished callback that arrives while the loss is processed does not overwrite it" do
      job = started_job()

      holder = finish_elsewhere(job.id, "failed", %{failure_reason: @terminated})

      payload = Poison.encode!(%{"result" => "passed"})
      callback = Poison.encode!(%{"job_hash_id" => job.id, "payload" => payload})

      JobFinishedCallbackWorker.handle_message(callback)
      assert {:ok, _} = Task.await(holder)

      {:ok, job} = Job.find(job.id)
      assert Job.failed?(job)
      assert job.failure_reason == @terminated
    end
  end
end
