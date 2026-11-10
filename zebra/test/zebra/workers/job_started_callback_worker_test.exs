defmodule Zebra.Workers.JobStartedCallbackWorkerTest do
  use Zebra.DataCase

  alias InternalApi.ServerFarm.MQ.JobStateExchange.JobStarted
  alias Zebra.Models.Job
  alias Zebra.Workers.JobStartedCallbackWorker, as: Worker

  @agent_id Ecto.UUID.generate()
  @agent_name "agent-name-00123"

  import Mock

  defp started_message(job_id) do
    JobStarted.new(
      job_id: job_id,
      agent_id: @agent_id,
      agent_name: @agent_name,
      timestamp: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()))
    )
    |> JobStarted.encode()
  end

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

    test "self-hosted job dispatched to a waiting agent => latency is emitted on start" do
      {:ok, job} = Support.Factories.Job.create(:scheduled, %{machine_type: "s1-testing"})

      # Current SHH does not return the agent on occupy: the job waits.
      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ ->
        %InternalApi.SelfHosted.OccupyAgentResponse{agent_id: "", agent_name: ""}
      end)

      with_mock Watchman, [:passthrough],
        submit: fn _, _, _ -> nil end,
        increment: fn _ -> nil end do
        Zebra.Workers.Dispatcher.process(job)
        assert Job.waiting_for_agent?(Job.reload(job))
        assert_not_called(Watchman.submit("job.dispatching.self_hosted.duration", :_, :_))

        Worker.handle_message(started_message(job.id))

        job = Job.reload(job)
        assert Job.started?(job)
        {:ok, ms} = Zebra.Time.datetime_diff_in_ms(job.started_at, job.scheduled_at)

        assert_called(Watchman.submit("job.dispatching.self_hosted.duration", ms, :timing))

        assert_called(
          Watchman.increment(
            {"job.dispatching.self_hosted.histogram", [job.organization_id, :_, :_]}
          )
        )

        assert_not_called(Watchman.submit("job.dispatching.duration", :_, :_))
        assert_not_called(Watchman.increment({"job.dispatching.histogram", :_}))
      end
    end

    test "cloud job started through the callback => no self-hosted latency" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      with_mock Watchman, [:passthrough],
        submit: fn _, _, _ -> nil end,
        increment: fn _ -> nil end do
        Worker.handle_message(started_message(job.id))

        assert Job.started?(Job.reload(job))
        assert_not_called(Watchman.submit("job.dispatching.self_hosted.duration", :_, :_))
        assert_not_called(Watchman.increment({"job.dispatching.self_hosted.histogram", :_}))
      end
    end

    test "already started self-hosted job => latency is not emitted twice" do
      {:ok, job} = Support.Factories.Job.create(:started, %{machine_type: "s1-testing"})

      with_mock Watchman, [:passthrough],
        submit: fn _, _, _ -> nil end,
        increment: fn _ -> nil end do
        Worker.handle_message(started_message(job.id))

        assert_not_called(Watchman.submit("job.dispatching.self_hosted.duration", :_, :_))
      end
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
