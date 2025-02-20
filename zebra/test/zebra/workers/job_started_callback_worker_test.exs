defmodule Zebra.Workers.JobStartedCallbackWorkerTest do
  use Zebra.DataCase

  alias InternalApi.ServerFarm.MQ.JobStateExchange.JobStarted
  alias Zebra.Models.Job
  alias Zebra.Workers.JobStartedCallbackWorker, as: Worker

  @agent_id Ecto.UUID.generate()
  @agent_name "agent-name-00123"

  describe ".handle_message" do
    test "when the job is waiting => handles a started callback message" do
      {:ok, job} = Support.Factories.Job.create(:"waiting-for-agent")

      message =
        JobStarted.new(
          job_id: job.id,
          agent_id: @agent_id,
          agent_name: @agent_name,
          timestamp: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()))
        )
        |> JobStarted.encode()

      Worker.handle_message(message)

      {:ok, job} = Job.find(job.id)

      assert Job.started?(job)
      refute is_nil(job.started_at)
    end

    test "when the job is already started => no error" do
      {:ok, job} = Support.Factories.Job.create(:started)

      message =
        JobStarted.new(
          job_id: job.id,
          agent_id: @agent_id,
          agent_name: @agent_name,
          timestamp: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()))
        )
        |> JobStarted.encode()

      Worker.handle_message(message)

      assert Job.started?(job)
      refute is_nil(job.started_at)
    end

    test "when the job is already finished => no error" do
      {:ok, job} = Support.Factories.Job.create(:finished)

      message =
        JobStarted.new(
          job_id: job.id,
          agent_id: @agent_id,
          agent_name: @agent_name,
          timestamp: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()))
        )
        |> JobStarted.encode()

      Worker.handle_message(message)

      assert Job.finished?(job)
      refute is_nil(job.started_at)
    end

    test "when job is not found => raise error" do
      message =
        JobStarted.new(
          job_id: Ecto.UUID.generate(),
          agent_id: @agent_id,
          agent_name: @agent_name,
          timestamp: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()))
        )
        |> JobStarted.encode()

      assert_raise MatchError, fn ->
        Worker.handle_message(message)
      end
    end
  end
end
