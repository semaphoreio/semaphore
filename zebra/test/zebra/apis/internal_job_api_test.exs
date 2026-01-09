defmodule Zebra.Api.InternalJobApiTest do
  # credo:disable-for-this-file Credo.Check.Design.DuplicatedCode

  alias Support.Factories
  use Zebra.DataCase

  @job_id Ecto.UUID.generate()

  describe ".list" do
    test "when page_size is too high => it returns error" do
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_states: [], page_size: 5000)

      assert {:ok, res} = Stub.list(channel, request)
      assert res.status.message == "Page size must be between 1 and 1000. Got 5000."
      assert res.status.code == InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
    end

    test "when every parameter is correct => it returns list of jobs" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, _} = Support.Factories.Job.create(:finished)
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_states: [Job.State.value(:FINISHED)])

      {:ok, reply} = Stub.list(channel, request)

      project_id = Factories.Job.project_id()
      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert [
               %InternalApi.ServerFarm.Job.Job{
                 branch_id: "",
                 agent_host: "1.2.3.4",
                 agent_ctrl_port: 443,
                 agent_auth_token: "lol",
                 failure_reason: "",
                 hook_id: "",
                 id: _,
                 index: 0,
                 machine_os_image: "ubuntu1804",
                 machine_type: "e1-standard-2",
                 name: "RSpec 1/3",
                 ppl_id: "",
                 project_id: ^project_id,
                 result: 0,
                 state: 4,
                 timeline: %InternalApi.ServerFarm.Job.Job.Timeline{
                   created_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                   enqueued_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                   execution_started_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                   execution_finished_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                   finished_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                   started_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _}
                 },
                 priority: 0,
                 is_debug_job: false
               }
             ] = reply.jobs
    end

    test "pagination" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      1..5
      |> Enum.each(fn _ ->
        {:ok, _} = Support.Factories.Job.create(:finished)
      end)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req1 =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          page_size: 3
        )

      {:ok, reply} = Stub.list(channel, req1)

      assert reply.next_page_token != ""
      assert length(reply.jobs) == 3

      req2 =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          page_size: 3,
          page_token: reply.next_page_token
        )

      {:ok, reply} = Stub.list(channel, req2)

      assert reply.next_page_token == ""
      assert length(reply.jobs) == 2
    end

    test "return only jobs that belong to one of given pipelines" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      ppl_id_1 = UUID.uuid4()
      ppl_id_2 = UUID.uuid4()
      ppl_id_3 = UUID.uuid4()

      {:ok, _} = Support.Factories.Task.create_jobs_valid_timestamps(%{ppl_id: ppl_id_1})
      :timer.sleep(1_000)
      {:ok, _} = Support.Factories.Task.create_jobs_valid_timestamps(%{ppl_id: ppl_id_2})
      :timer.sleep(1_000)
      {:ok, _} = Support.Factories.Task.create_jobs_valid_timestamps(%{ppl_id: ppl_id_3})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        Request.new(
          job_states: [Job.State.value(:STARTED)],
          ppl_ids: [ppl_id_1, ppl_id_3],
          order: Request.Order.value(:BY_CREATION_TIME_DESC),
          page_size: 5
        )

      {:ok, reply} = Stub.list(channel, req)
      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert [
               %InternalApi.ServerFarm.Job.Job{
                 index: 0,
                 ppl_id: ^ppl_id_3,
                 state: 3,
                 priority: 0,
                 is_debug_job: false
               },
               %InternalApi.ServerFarm.Job.Job{
                 index: 0,
                 ppl_id: ^ppl_id_1,
                 state: 3,
                 priority: 0,
                 is_debug_job: false
               }
             ] = reply.jobs
    end

    test "return only debug jobs and filter by org_id" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      org_id_1 = UUID.uuid4()
      org_id_2 = UUID.uuid4()

      {:ok, job_1} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Regular Job 1"))

      {:ok, d_job_1} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Debug Job 1"))

      {:ok, _debug} = Support.Factories.Debug.create_for_job(job_1.id, d_job_1.id)
      :timer.sleep(1_000)

      {:ok, job_2} =
        Support.Factories.Job.create(:finished, job_params(org_id_2, "Regular Job 2"))

      {:ok, d_job_2} =
        Support.Factories.Job.create(:finished, job_params(org_id_2, "Debug Job 2"))

      {:ok, _debug} = Support.Factories.Debug.create_for_job(job_2.id, d_job_2.id)
      :timer.sleep(1_000)

      {:ok, job_3} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Regular Job 3"))

      {:ok, d_job_3} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Debug Job 3"))

      {:ok, _debug} = Support.Factories.Debug.create_for_job(job_3.id, d_job_3.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          organization_id: org_id_1,
          only_debug_jobs: true,
          order: Request.Order.value(:BY_CREATION_TIME_DESC),
          page_size: 5
        )

      {:ok, reply} = Stub.list(channel, req)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert [
               %InternalApi.ServerFarm.Job.Job{
                 name: "Debug Job 3",
                 project_id: id_1,
                 state: 4,
                 priority: 0,
                 is_debug_job: true
               },
               %InternalApi.ServerFarm.Job.Job{
                 name: "Debug Job 1",
                 project_id: id_2,
                 state: 4,
                 priority: 0,
                 is_debug_job: true
               }
             ] = reply.jobs

      assert id_1 == org_id_1
      assert id_2 == org_id_1
    end

    test "returns only jobs in created_at range" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      month_ago = DateTime.utc_now() |> DateTime.add(-3_600 * 24 * 30, :second)
      week_ago = DateTime.utc_now() |> DateTime.add(-3_600 * 24 * 7, :second)
      {:ok, _} = Support.Factories.Job.create(:finished, %{created_at: month_ago})
      {:ok, _} = Support.Factories.Job.create(:finished, %{created_at: month_ago})
      {:ok, _} = Support.Factories.Job.create(:finished, %{created_at: DateTime.utc_now()})
      {:ok, _} = Support.Factories.Job.create(:finished, %{created_at: DateTime.utc_now()})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          order: Request.Order.value(:BY_CREATION_TIME_DESC),
          created_at_gte: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(month_ago)),
          created_at_lte: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(week_ago))
        )

      {:ok, reply} = Stub.list(channel, req)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)
      assert length(reply.jobs) == 2
    end

    test "returns empty list if job for machine type does not exist" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, _} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-2"})
      {:ok, _} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-4"})
      {:ok, _} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-8"})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          machine_types: ["f1-standard-2"]
        )

      {:ok, reply} = Stub.list(channel, req)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)
      assert Enum.empty?(reply.jobs)
    end

    test "returns only jobs for specified machine_types" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, %{id: j1}} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-2"})
      {:ok, %{id: j2}} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-4"})
      {:ok, %{id: j3}} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-8"})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          machine_types: ["e1-standard-2", "e1-standard-4"]
        )

      {:ok, reply} = Stub.list(channel, req)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)
      assert length(reply.jobs) == 2
      assert Enum.any?(reply.jobs, fn j -> j.id == j1 end)
      assert Enum.any?(reply.jobs, fn j -> j.id == j2 end)
      refute Enum.any?(reply.jobs, fn j -> j.id == j3 end)
    end

    test "returns jobs for all machine types if no machine types are specified" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, %{id: j1}} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-2"})
      {:ok, %{id: j2}} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-4"})
      {:ok, %{id: j3}} = Support.Factories.Job.create(:finished, %{machine_type: "e1-standard-8"})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Request.new(job_states: [Job.State.value(:FINISHED)])

      {:ok, reply} = Stub.list(channel, req)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)
      assert length(reply.jobs) == 3
      assert Enum.any?(reply.jobs, fn j -> j.id == j1 end)
      assert Enum.any?(reply.jobs, fn j -> j.id == j2 end)
      assert Enum.any?(reply.jobs, fn j -> j.id == j3 end)
    end
  end

  defp job_params(org_id, name),
    do: %{name: name, organization_id: org_id, project_id: org_id, created_at: DateTime.utc_now()}

  describe ".count" do
    test "returns count of jobs" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.CountRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      1..5
      |> Enum.each(fn _ ->
        {:ok, _} = Support.Factories.Job.create(:finished)
      end)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      # this test will fail on: 18 May 2033, :troll:
      req1 =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          finished_at_gte: Google.Protobuf.Timestamp.new(seconds: 0),
          finished_at_lte: Google.Protobuf.Timestamp.new(seconds: 2_000_000_000)
        )

      {:ok, res} = Stub.count(channel, req1)

      assert res.status.code == InternalApi.ResponseStatus.Code.value(:OK)
      assert res.count == 5
    end
  end

  describe ".count_by_state" do
    alias InternalApi.ServerFarm.Job.Job
    alias InternalApi.ServerFarm.Job.CountByStateRequest, as: Request
    alias InternalApi.ServerFarm.Job.CountByStateResponse.CountByState, as: CountByState
    alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

    test "returns empty if no states specified" do
      {:ok, _job} = Support.Factories.Job.create(:started)
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, res} =
        Stub.count_by_state(
          channel,
          Request.new(
            org_id: Factories.Job.org_id(),
            agent_type: "e1-standard-2"
          )
        )

      assert res.counts == []
    end

    test "only returns counts for requested states" do
      {:ok, _job} = Support.Factories.Job.create(:pending)
      {:ok, _job} = Support.Factories.Job.create(:enqueued)
      {:ok, _job} = Support.Factories.Job.create(:scheduled)
      {:ok, _job} = Support.Factories.Job.create(:scheduled)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, res} =
        Stub.count_by_state(
          channel,
          Request.new(
            org_id: Factories.Job.org_id(),
            agent_type: "e1-standard-2",
            states: [Job.State.value(:ENQUEUED), Job.State.value(:SCHEDULED)]
          )
        )

      assert res.counts == [
               %CountByState{
                 state: Job.State.value(:ENQUEUED),
                 count: 1
               },
               %CountByState{
                 state: Job.State.value(:SCHEDULED),
                 count: 2
               }
             ]
    end

    test "finished jobs are not counted" do
      {:ok, _job} = Support.Factories.Job.create(:pending)
      {:ok, _job} = Support.Factories.Job.create(:scheduled)
      {:ok, _job} = Support.Factories.Job.create(:scheduled)
      {:ok, _job} = Support.Factories.Job.create(:finished)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, res} =
        Stub.count_by_state(
          channel,
          Request.new(
            org_id: Factories.Job.org_id(),
            agent_type: "e1-standard-2",
            states: [
              Job.State.value(:PENDING),
              Job.State.value(:SCHEDULED),
              Job.State.value(:FINISHED)
            ]
          )
        )

      assert res.counts == [
               %CountByState{
                 state: Job.State.value(:PENDING),
                 count: 1
               },
               %CountByState{
                 state: Job.State.value(:SCHEDULED),
                 count: 2
               }
             ]
    end

    test "requested state count is returned even if no jobs exist for that state" do
      {:ok, _job} = Support.Factories.Job.create(:scheduled)
      {:ok, _job} = Support.Factories.Job.create(:scheduled)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, res} =
        Stub.count_by_state(
          channel,
          Request.new(
            org_id: Factories.Job.org_id(),
            agent_type: "e1-standard-2",
            states: [Job.State.value(:SCHEDULED), Job.State.value(:STARTED)]
          )
        )

      assert res.counts == [
               %CountByState{
                 state: Job.State.value(:SCHEDULED),
                 count: 2
               },
               %CountByState{
                 state: Job.State.value(:STARTED),
                 count: 0
               }
             ]
    end
  end

  describe ".describe" do
    test "job is found" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.DescribeRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      agent_id = Ecto.UUID.generate()
      {:ok, job} = Support.Factories.Job.create(:finished, %{agent_id: agent_id})
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Request.new(job_id: job.id)
      {:ok, res} = Stub.describe(channel, req)

      project_id = Factories.Job.project_id()
      assert res.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert %InternalApi.ServerFarm.Job.Job{
               branch_id: "",
               agent_id: ^agent_id,
               agent_host: "1.2.3.4",
               agent_ctrl_port: 443,
               agent_auth_token: "lol",
               failure_reason: "",
               hook_id: "",
               id: _,
               index: 0,
               machine_os_image: "ubuntu1804",
               machine_type: "e1-standard-2",
               name: "RSpec 1/3",
               ppl_id: "",
               project_id: ^project_id,
               result: 0,
               state: 4,
               timeline: %InternalApi.ServerFarm.Job.Job.Timeline{
                 created_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 enqueued_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 execution_finished_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 execution_started_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 finished_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 started_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _}
               },
               priority: 0,
               is_debug_job: false,
               self_hosted: false
             } = res.job
    end

    test "self hosted job is found" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.DescribeRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      agent_id = Ecto.UUID.generate()

      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          machine_type: "s1-custom-linux",
          agent_id: agent_id
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Request.new(job_id: job.id)
      {:ok, res} = Stub.describe(channel, req)

      project_id = Factories.Job.project_id()
      assert res.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert %InternalApi.ServerFarm.Job.Job{
               branch_id: "",
               agent_id: ^agent_id,
               agent_host: "1.2.3.4",
               agent_ctrl_port: 443,
               agent_auth_token: "lol",
               failure_reason: "",
               hook_id: "",
               id: _,
               index: 0,
               machine_os_image: "ubuntu1804",
               machine_type: "s1-custom-linux",
               name: "RSpec 1/3",
               ppl_id: "",
               project_id: ^project_id,
               result: 0,
               state: 4,
               timeline: %InternalApi.ServerFarm.Job.Job.Timeline{
                 created_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 enqueued_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 execution_finished_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 execution_started_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 finished_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _},
                 started_at: %Google.Protobuf.Timestamp{nanos: 0, seconds: _}
               },
               priority: 0,
               is_debug_job: false,
               self_hosted: true
             } = res.job
    end

    test "job not found" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.DescribeRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Request.new(job_id: Ecto.UUID.generate())
      {:ok, res} = Stub.describe(channel, req)

      assert res.status.code == InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
      assert res.status.message == "Job with id #{req.job_id} not found"
    end
  end

  describe ".list_debug_sessions" do
    alias InternalApi.ServerFarm.Job.ListDebugSessionsRequest, as: Request
    alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub
    alias InternalApi.ServerFarm.Job.Job
    alias InternalApi.ServerFarm.Job.DebugSessionType

    test "when page_size is too high => it returns error" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_states: [], page_size: 5000)

      assert {:ok, res} = Stub.list_debug_sessions(channel, request)
      assert res.status.message == "Page size must be between 1 and 1000. Got 5000."
      assert res.status.code == InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
    end

    test "when every parameter is correct => it returns list of jobs" do
      {:ok, _} = Support.Factories.Debug.create()
      {:ok, _} = Support.Factories.Debug.create()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request =
        Request.new(
          debug_session_states: [
            Job.State.value(:PENDING),
            Job.State.value(:ENQUEUED),
            Job.State.value(:SCHEDULED),
            Job.State.value(:STARTED)
          ],
          types: [DebugSessionType.value(:JOB)]
        )

      {:ok, reply} = Stub.list_debug_sessions(channel, request)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)
      assert length(reply.debug_sessions) == 2
      assert Enum.at(reply.debug_sessions, 0).debugged_job != nil
    end

    test "pagination" do
      1..5 |> Enum.each(fn _ -> {:ok, _} = Support.Factories.Debug.create() end)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req1 =
        Request.new(
          debug_session_states: [
            Job.State.value(:PENDING),
            Job.State.value(:ENQUEUED),
            Job.State.value(:SCHEDULED),
            Job.State.value(:STARTED)
          ],
          types: [DebugSessionType.value(:JOB)],
          page_size: 3
        )

      {:ok, reply} = Stub.list_debug_sessions(channel, req1)

      assert reply.next_page_token != ""
      assert length(reply.debug_sessions) == 3

      req2 =
        Request.new(
          debug_session_states: [
            Job.State.value(:PENDING),
            Job.State.value(:ENQUEUED),
            Job.State.value(:SCHEDULED),
            Job.State.value(:STARTED)
          ],
          types: [DebugSessionType.value(:JOB)],
          page_size: 3,
          page_token: reply.next_page_token
        )

      {:ok, reply} = Stub.list_debug_sessions(channel, req2)

      assert reply.next_page_token == ""
      assert length(reply.debug_sessions) == 2
    end

    test "return only jobs that belong to one of given pipelines" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      ppl_id_1 = UUID.uuid4()
      ppl_id_2 = UUID.uuid4()
      ppl_id_3 = UUID.uuid4()

      {:ok, _} = Support.Factories.Task.create_jobs_valid_timestamps(%{ppl_id: ppl_id_1})
      :timer.sleep(1_000)
      {:ok, _} = Support.Factories.Task.create_jobs_valid_timestamps(%{ppl_id: ppl_id_2})
      :timer.sleep(1_000)
      {:ok, _} = Support.Factories.Task.create_jobs_valid_timestamps(%{ppl_id: ppl_id_3})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        Request.new(
          job_states: [Job.State.value(:STARTED)],
          ppl_ids: [ppl_id_1, ppl_id_3],
          order: Request.Order.value(:BY_CREATION_TIME_DESC),
          page_size: 5
        )

      {:ok, reply} = Stub.list(channel, req)
      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert [
               %InternalApi.ServerFarm.Job.Job{
                 index: 0,
                 ppl_id: ^ppl_id_3,
                 state: 3,
                 priority: 0,
                 is_debug_job: false
               },
               %InternalApi.ServerFarm.Job.Job{
                 index: 0,
                 ppl_id: ^ppl_id_1,
                 state: 3,
                 priority: 0,
                 is_debug_job: false
               }
             ] = reply.jobs
    end

    test "return only debug jobs and filter by org_id" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.ListRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      org_id_1 = UUID.uuid4()
      org_id_2 = UUID.uuid4()

      {:ok, job_1} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Regular Job 1"))

      {:ok, d_job_1} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Debug Job 1"))

      {:ok, _debug} = Support.Factories.Debug.create_for_job(job_1.id, d_job_1.id)
      :timer.sleep(1_000)

      {:ok, job_2} =
        Support.Factories.Job.create(:finished, job_params(org_id_2, "Regular Job 2"))

      {:ok, d_job_2} =
        Support.Factories.Job.create(:finished, job_params(org_id_2, "Debug Job 2"))

      {:ok, _debug} = Support.Factories.Debug.create_for_job(job_2.id, d_job_2.id)
      :timer.sleep(1_000)

      {:ok, job_3} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Regular Job 3"))

      {:ok, d_job_3} =
        Support.Factories.Job.create(:finished, job_params(org_id_1, "Debug Job 3"))

      {:ok, _debug} = Support.Factories.Debug.create_for_job(job_3.id, d_job_3.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        Request.new(
          job_states: [Job.State.value(:FINISHED)],
          organization_id: org_id_1,
          only_debug_jobs: true,
          order: Request.Order.value(:BY_CREATION_TIME_DESC),
          page_size: 5
        )

      {:ok, reply} = Stub.list(channel, req)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert [
               %InternalApi.ServerFarm.Job.Job{
                 name: "Debug Job 3",
                 project_id: id_1,
                 state: 4,
                 priority: 0,
                 is_debug_job: true
               },
               %InternalApi.ServerFarm.Job.Job{
                 name: "Debug Job 1",
                 project_id: id_2,
                 state: 4,
                 priority: 0,
                 is_debug_job: true
               }
             ] = reply.jobs

      assert id_1 == org_id_1
      assert id_2 == org_id_1
    end
  end

  describe ".total_execution_time" do
    test "when the org_id exists => calulate total time of all jobs" do
      alias InternalApi.ServerFarm.Job.TotalExecutionTimeRequest, as: Request
      alias InternalApi.ServerFarm.Job.TotalExecutionTimeResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub
      alias Support.Factories.Job
      alias Support.Time

      org_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Job.create(:started, %{
          organization_id: org_id,
          created_at: now,
          started_at: Time.ago(minutes: 15)
        })

      {:ok, j2} =
        Job.create(:finished, %{
          organization_id: org_id,
          created_at: now,
          started_at: Time.ago(minutes: 10),
          finished_at: Time.ago(minutes: 2)
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Request.new(org_id: j2.organization_id)
      {:ok, reply} = Stub.total_execution_time(channel, req)

      assert reply.total_duration_in_secs >= 23 * 60
      assert reply.total_duration_in_secs <= 24 * 60
    end
  end

  describe ".stop" do
    test "when the job is present => requests an async stop" do
      alias Zebra.Models.{Job, JobStopRequest}

      alias InternalApi.ServerFarm.Job.StopRequest, as: Request
      alias InternalApi.ServerFarm.Job.StopResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, job} = Support.Factories.Job.create(:started, %{})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id, requester_id: "user_1")

      job = Job.reload(job)

      assert {:ok, %Response{status: %{code: 0}}} = channel |> Stub.stop(request)

      assert {:ok, stop_request} = JobStopRequest.find_by_job_id(job.id)

      assert stop_request != nil
      assert stop_request.job_id == job.id
    end

    test "idempotent requests" do
      alias Zebra.Models.JobStopRequest

      alias InternalApi.ServerFarm.Job.StopRequest, as: Request
      alias InternalApi.ServerFarm.Job.StopResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, job} = Support.Factories.Job.create(:started, %{})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id, requester_id: "user_1")

      1..3
      |> Enum.each(fn _ ->
        assert {:ok, %Response{status: %{code: 0}}} = channel |> Stub.stop(request)
      end)

      assert {:ok, stop_request} = JobStopRequest.find_by_job_id(job.id)
      assert stop_request != nil
      assert stop_request.job_id == job.id
    end

    test "when the job is not found => returns not found" do
      alias InternalApi.ServerFarm.Job.StopRequest, as: Request
      alias InternalApi.ServerFarm.Job.StopResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: @job_id)

      assert {:ok, %Response{status: %{code: 1, message: message}}} =
               channel |> Stub.stop(request)

      assert message == "Job with id: '#{@job_id}' not found"
    end
  end

  describe ".get_agent_payload" do
    test "when the job is present => returns payload" do
      alias InternalApi.ServerFarm.Job.GetAgentPayloadRequest, as: Request
      alias InternalApi.ServerFarm.Job.GetAgentPayloadResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, job} = Support.Factories.Job.create(:started, %{})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      assert {:ok, %Response{payload: payload}} = Stub.get_agent_payload(channel, request)
      assert payload == Poison.encode!(job.request)
    end

    test "when the job is not present => returns :not found" do
      alias InternalApi.ServerFarm.Job.GetAgentPayloadRequest, as: Request
      alias InternalApi.ServerFarm.Job.GetAgentPayloadResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: Ecto.UUID.generate())

      assert {:error, %GRPC.RPCError{message: "Not found", status: 5}} =
               Stub.get_agent_payload(channel, request)
    end
  end

  describe ".can_debug" do
    test "when the job is present => returns proper status" do
      alias InternalApi.ServerFarm.Job.CanDebugRequest, as: Request
      alias InternalApi.ServerFarm.Job.CanDebugResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      alias Zebra.Apis.DebugPermissions

      {:ok, job} = Support.Factories.Job.create(:started, %{})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      with_mock DebugPermissions, check: fn _, _, :debug -> {:ok, true} end do
        request = Request.new(job_id: job.id)

        assert {:ok, %Response{allowed: true}} = Stub.can_debug(channel, request)
      end
    end

    test "when the job is not present => returns :not found" do
      alias InternalApi.ServerFarm.Job.CanDebugRequest, as: Request
      alias InternalApi.ServerFarm.Job.CanDebugResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: @job_id)

      assert {:error, %GRPC.RPCError{message: message, status: 5}} =
               Stub.can_debug(channel, request)

      assert message == "Job with id: '#{@job_id}' not found"
    end
  end

  describe ".can_attach" do
    test "when the job is present => returns proper status" do
      alias InternalApi.ServerFarm.Job.CanAttachRequest, as: Request
      alias InternalApi.ServerFarm.Job.CanAttachResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      alias Zebra.Apis.DebugPermissions
      alias Zebra.Apis.DeploymentTargets

      {:ok, job} = Support.Factories.Job.create(:started, %{})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      with_mocks [
        {DebugPermissions, [], check: fn _, _, :attach -> {:ok, true} end},
        {DeploymentTargets, [], can_run?: fn _, _ -> {:ok, true} end}
      ] do
        request = Request.new(job_id: job.id)

        assert {:ok, %Response{allowed: true}} = Stub.can_attach(channel, request)
      end
    end

    test "when deployment target prevents attaching to job => returns proper status" do
      alias InternalApi.ServerFarm.Job.CanAttachRequest, as: Request
      alias InternalApi.ServerFarm.Job.CanAttachResponse, as: Response
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      alias Zebra.Apis.DebugPermissions
      alias Zebra.Apis.DeploymentTargets

      {:ok, job} = Support.Factories.Job.create(:started, %{})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      with_mocks [
        {DebugPermissions, [], check: fn _, _, :attach -> {:ok, true} end},
        {DeploymentTargets, [],
         can_run?: fn _, _ ->
           {:error, :permission_denied, "You are not allowed to access Deployment Target"}
         end}
      ] do
        request = Request.new(job_id: job.id)

        assert {:ok,
                %Response{
                  allowed: false,
                  message: "You are not allowed to access Deployment Target"
                }} = Stub.can_attach(channel, request)
      end
    end

    test "when the job is not present => returns :not found" do
      alias InternalApi.ServerFarm.Job.CanAttachRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: @job_id)

      assert {:error, %GRPC.RPCError{message: message, status: 5}} =
               Stub.can_attach(channel, request)

      assert message == "Job with id: '#{@job_id}' not found"
    end
  end

  describe ".create" do
    test "when params are invalid => return error message" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.JobSpec
      alias InternalApi.ServerFarm.Job.CreateRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      organization_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      valid_request =
        Request.new(
          requester_id: Ecto.UUID.generate(),
          organization_id: organization_id,
          project_id: project_id,
          branch_name: "master",
          commit_sha: "",
          restricted_job: false,
          job_spec: %JobSpec{
            job_name: "RSpec 1/3",
            agent: %JobSpec.Agent{
              machine: %JobSpec.Agent.Machine{
                os_image: "ubuntu2204",
                type: "e2-standard-2"
              },
              containers: [],
              image_pull_secrets: []
            },
            secrets: [],
            env_vars: [],
            files: [],
            commands: [
              "echo 1234"
            ],
            epilogue_always_commands: [],
            epilogue_on_pass_commands: [],
            epilogue_on_fail_commands: [],
            priority: 0,
            execution_time_limit: 0
          }
        )

      request = %{valid_request | project_id: ""}
      assert {:ok, reply} = Stub.create(channel, request)
      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
      assert reply.status.message == "Invalid parameter 'project_id' - must be a valid UUID."

      spec = %{valid_request.job_spec | job_name: ""}
      request = %{valid_request | job_spec: spec}
      assert {:ok, reply} = Stub.create(channel, request)
      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
      assert reply.status.message == "The 'job_name' field value must be a non-empty string."

      spec = %{valid_request.job_spec | commands: []}
      request = %{valid_request | job_spec: spec}
      assert {:ok, reply} = Stub.create(channel, request)
      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
      assert reply.status.message == "The 'commands' list must contain at least one command."

      agent = %JobSpec.Agent{
        machine: %JobSpec.Agent.Machine{
          os_image: "",
          type: ""
        },
        containers: [],
        image_pull_secrets: []
      }

      spec = %{valid_request.job_spec | agent: agent}
      request = %{valid_request | job_spec: spec}
      assert {:ok, reply} = Stub.create(channel, request)
      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:BAD_PARAM)

      assert reply.status.message ==
               "The 'agent -> machine ->type' field value must be a non-empty string."
    end

    test "when all params are ok => return job" do
      alias InternalApi.ServerFarm.Job.Job
      alias InternalApi.ServerFarm.Job.JobSpec
      alias InternalApi.ServerFarm.Job.CreateRequest, as: Request
      alias InternalApi.ServerFarm.Job.JobService.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      organization_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      request =
        Request.new(
          requester_id: Ecto.UUID.generate(),
          organization_id: organization_id,
          project_id: project_id,
          branch_name: "master",
          commit_sha: "",
          restricted_job: false,
          job_spec: %JobSpec{
            job_name: "RSpec 1/3",
            agent: %JobSpec.Agent{
              machine: %JobSpec.Agent.Machine{
                os_image: "ubuntu2204",
                type: "e2-standard-2"
              },
              containers: [],
              image_pull_secrets: []
            },
            secrets: [],
            env_vars: [],
            files: [],
            commands: [
              "echo 1234"
            ],
            epilogue_always_commands: [],
            epilogue_on_pass_commands: [],
            epilogue_on_fail_commands: [],
            priority: 200,
            execution_time_limit: 0
          }
        )

      assert {:ok, reply} = Stub.create(channel, request)

      assert reply.status.code == InternalApi.ResponseStatus.Code.value(:OK)

      assert %Job{
               index: 0,
               is_debug_job: false,
               machine_os_image: "ubuntu2204",
               machine_type: "e2-standard-2",
               name: "RSpec 1/3",
               organization_id: ^organization_id,
               ppl_id: "",
               priority: 50,
               project_id: ^project_id,
               self_hosted: false
             } = reply.job
    end
  end
end
