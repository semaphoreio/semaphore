defmodule Zebra.Models.JobTest do
  use Zebra.DataCase

  alias Zebra.Models.Job
  alias Zebra.Workers.Agent.HostedAgent, as: Agent

  @org_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()
  @agent_id Ecto.UUID.generate()

  describe ".create" do
    test "empty name => error" do
      assert {:error, "name: can't be blank"} =
               Zebra.Models.Job.create(
                 organization_id: @org_id,
                 project_id: @project_id,
                 index: 0,
                 priority: 75,
                 spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
                 machine_type: "e1-standard-2",
                 machine_os_image: "ubuntu1804"
               )
    end

    test "empty organization_id => error" do
      assert {:error, "organization_id: can't be blank"} =
               Zebra.Models.Job.create(
                 project_id: @project_id,
                 index: 0,
                 priority: 75,
                 name: "Test",
                 spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
                 machine_type: "e1-standard-2",
                 machine_os_image: "ubuntu1804"
               )
    end

    test "empty project_id => error" do
      assert {:error, "project_id: can't be blank"} =
               Zebra.Models.Job.create(
                 organization_id: @org_id,
                 index: 0,
                 priority: 75,
                 name: "Test",
                 spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
                 machine_type: "e1-standard-2",
                 machine_os_image: "ubuntu1804"
               )
    end

    test "creates a new job" do
      spec = %Semaphore.Jobs.V1alpha.Job.Spec{
        agent: %Semaphore.Jobs.V1alpha.Job.Spec.Agent{
          machine: %Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine{
            type: "e1-standard-2",
            os_image: "ubuntu1804"
          }
        },
        project_id: @project_id
      }

      {:ok, job} =
        Zebra.Models.Job.create(
          organization_id: @org_id,
          project_id: @project_id,
          name: "test",
          index: 0,
          priority: 75,
          spec: spec,
          machine_type: "e1-standard-2",
          machine_os_image: "ubuntu1804"
        )

      assert job.organization_id == @org_id
      assert job.project_id == @project_id
      assert job.name == "test"
      assert job.index == 0
      assert job.priority == 75
      assert job.spec == Job.encode_spec(spec)
      assert job.machine_type == "e1-standard-2"
      assert job.machine_os_image == "ubuntu1804"
    end

    test "when machine_os_image is blank => it sets the default os_image for the machine_type" do
      {:ok, job1} =
        Zebra.Models.Job.create(
          organization_id: @org_id,
          project_id: @project_id,
          name: "test",
          spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
          machine_type: "e1-standard-2"
        )

      {:ok, job2} =
        Zebra.Models.Job.create(
          organization_id: @org_id,
          project_id: @project_id,
          name: "test",
          spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
          machine_type: "a1-standard-4"
        )

      assert job1.machine_os_image == "ubuntu1804"
      assert job2.machine_os_image == "macos-xcode13"
    end

    test "when machine_os_image is blank and the machine type is unknown => it leaves the os_image blank" do
      {:ok, job} =
        Zebra.Models.Job.create(
          organization_id: @org_id,
          project_id: @project_id,
          name: "test",
          spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
          machine_type: "x1-standard-4"
        )

      assert job.machine_os_image == ""
    end

    test "when the machine_os_image is set => it leaves it intact" do
      {:ok, job} =
        Zebra.Models.Job.create(
          organization_id: @org_id,
          project_id: @project_id,
          name: "test",
          spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
          machine_type: "x1-standard-4",
          machine_os_image: "xubuntu"
        )

      assert job.machine_os_image == "xubuntu"
    end

    test "it sets created_at and updated_at" do
      {:ok, job} =
        Zebra.Models.Job.create(
          organization_id: @org_id,
          project_id: @project_id,
          name: "test",
          spec: %Semaphore.Jobs.V1alpha.Job.Spec{},
          machine_type: "e1-standard-2"
        )

      assert job.created_at != nil
      assert job.updated_at != nil

      assert job.created_at == job.updated_at
    end
  end

  describe ".update" do
    test "it updates updated_at" do
      {:ok, job} = Support.Factories.Job.create(:pending)

      :timer.sleep(1000)

      old_updated_at = job.updated_at

      {:ok, job} = job |> Zebra.Models.Job.update()

      new_updated_at = job.updated_at

      assert old_updated_at < new_updated_at
    end

    test "it updates the fields" do
      {:ok, job} = Support.Factories.Job.create(:pending)
      assert job.result != "passed"

      {:ok, job} = job |> Zebra.Models.Job.update(%{result: "passed"})

      assert job.result == "passed"
    end
  end

  describe ".force_finish" do
    test "forcefully finished the job with failed status and a reason" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      assert {:ok, job} = Job.force_finish(job, "Santa said that he was naughty")

      assert Job.finished?(job)
      assert Job.failed?(job)
      assert job.failure_reason == "Santa said that he was naughty"
    end

    test "tries to finish the task" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:scheduled, %{build_id: task.id})

      assert {:ok, job} = Job.force_finish(job, "Santa said that he was naughty")

      task = Zebra.Models.Task |> where([t], t.id == ^task.id) |> Zebra.LegacyRepo.one()

      assert Job.finished?(job)
      assert Job.failed?(job)
      assert job.failure_reason == "Santa said that he was naughty"
      assert Zebra.Models.Task.finished?(task)
    end
  end

  describe ".bulk_force_finish" do
    test "force fails a list of jobs" do
      {:ok, job1} = Support.Factories.Job.create(:enqueued)
      {:ok, job2} = Support.Factories.Job.create(:enqueued)

      Zebra.Models.Job.bulk_force_finish([job1.id, job2.id], "They were bad")

      job1 = Zebra.Models.Job.reload(job1)
      job2 = Zebra.Models.Job.reload(job2)

      assert job1.aasm_state == "finished"
      assert job1.result == "failed"
      refute is_nil(job1.finished_at)

      assert job2.aasm_state == "finished"
      assert job2.result == "failed"
      refute is_nil(job2.finished_at)
    end
  end

  describe ".enqueue" do
    test "when the job is pending => saves request" do
      {:ok, job} = Support.Factories.Job.create(:pending)

      request = %{"fake" => "request"}
      rsa = Zebra.RSA.generate()

      assert {:ok, _} = Job.enqueue(job, request, rsa)
    end

    test "when the job is enqueued => error" do
      {:ok, job} = Support.Factories.Job.create(:enqueued)

      assert {:error, :invalid_transition} = Job.enqueue(job, %{}, nil)
    end

    test "when the job is scheduled => error" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      assert {:error, :invalid_transition} = Job.enqueue(job, %{}, nil)
    end

    test "when the job is waiting => error" do
      {:ok, job} = Support.Factories.Job.create(:"waiting-for-agent")

      assert {:error, :invalid_transition} = Job.enqueue(job, %{}, nil)
    end

    test "when the job is started => error" do
      {:ok, job} = Support.Factories.Job.create(:started)

      assert {:error, :invalid_transition} = Job.enqueue(job, %{}, nil)
    end

    test "when the job is finished => error" do
      {:ok, job} = Support.Factories.Job.create(:finished)

      assert {:error, :invalid_transition} = Job.enqueue(job, %{}, nil)
    end
  end

  describe ".schedule" do
    test "when the job is pending => error" do
      {:ok, job} = Support.Factories.Job.create(:pending)

      assert {:error, :invalid_transition} = Job.schedule(job)
    end

    test "when the job is enqueued => error" do
      {:ok, job} = Support.Factories.Job.create(:enqueued)

      assert {:ok, job} = Job.schedule(job)
      assert Job.scheduled?(job)
      refute is_nil(job.scheduled_at)
    end

    test "when the job is scheduled => transitions" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      assert {:error, :invalid_transition} = Job.schedule(job)
    end

    test "when the job is waiting => error" do
      {:ok, job} = Support.Factories.Job.create(:"waiting-for-agent")

      assert {:error, :invalid_transition} = Job.schedule(job)
    end

    test "when the job is started => error" do
      {:ok, job} = Support.Factories.Job.create(:started)

      assert {:error, :invalid_transition} = Job.schedule(job)
    end

    test "when the job is finished => error" do
      {:ok, job} = Support.Factories.Job.create(:finished, %{result: "passed"})

      assert {:error, :invalid_transition} = Job.schedule(job)
    end
  end

  describe ".bulk_schedule" do
    test "schedules jobs in a bulk" do
      {:ok, job1} = Support.Factories.Job.create(:enqueued)
      {:ok, job2} = Support.Factories.Job.create(:enqueued)

      Zebra.Models.Job.bulk_schedule([job1.id, job2.id])

      job1 = Zebra.Models.Job.reload(job1)
      job2 = Zebra.Models.Job.reload(job2)

      assert job1.aasm_state == "scheduled"
      refute is_nil(job1.scheduled_at)

      assert job2.aasm_state == "scheduled"
      refute is_nil(job2.scheduled_at)
    end
  end

  describe ".wait" do
    test "when the job is pending => error" do
      {:ok, job} = Support.Factories.Job.create(:pending)

      assert {:error, :invalid_transition} = Job.wait_for_agent(job)
    end

    test "when the job is enqueued => error" do
      {:ok, job} = Support.Factories.Job.create(:enqueued)

      assert {:error, :invalid_transition} = Job.wait_for_agent(job)
    end

    test "when the job is scheduled => transitions" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      assert {:ok, job} = Job.wait_for_agent(job)
      assert Job.waiting_for_agent?(job)
    end

    test "when the job is waiting => error" do
      {:ok, job} = Support.Factories.Job.create(:"waiting-for-agent")

      assert {:error, :invalid_transition} = Job.wait_for_agent(job)
    end

    test "when the job is started => error" do
      {:ok, job} = Support.Factories.Job.create(:started)

      assert {:error, :invalid_transition} = Job.wait_for_agent(job)
    end

    test "when the job is finished => error" do
      {:ok, job} = Support.Factories.Job.create(:finished, %{result: "passed"})

      assert {:error, :invalid_transition} = Job.wait_for_agent(job)
    end
  end

  describe ".start" do
    test "when the job is pending => error" do
      {:ok, job} = Support.Factories.Job.create(:pending)

      agent = %Agent{
        id: @agent_id,
        ip_address: "1.2.3.4",
        ctrl_port: 80
      }

      assert {:error, :invalid_transition} = Job.start(job, agent)
    end

    test "when the job is enqueued => error" do
      {:ok, job} = Support.Factories.Job.create(:enqueued)

      agent = %Agent{
        id: @agent_id,
        ip_address: "1.2.3.4",
        ctrl_port: 80
      }

      assert {:error, :invalid_transition} = Job.start(job, agent)
    end

    test "when the job is scheduled => transitions" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      agent = %Agent{
        id: @agent_id,
        ip_address: "1.2.3.4",
        ctrl_port: 80
      }

      assert {:ok, job} = Job.start(job, agent)
      assert Job.started?(job)
      refute is_nil(job.started_at)
      assert job.agent_id == agent.id
      assert job.agent_ip_address == agent.ip_address
      assert job.agent_ctrl_port == agent.ctrl_port
    end

    test "when the job is waiting => transitions" do
      {:ok, job} = Support.Factories.Job.create(:"waiting-for-agent")

      agent = %Agent{
        id: @agent_id,
        name: "agent-007",
        ip_address: nil,
        ctrl_port: nil,
        auth_token: nil,
        ssh_port: nil
      }

      assert {:ok, job} = Job.start(job, agent)
      assert Job.started?(job)
      refute is_nil(job.started_at)
      assert job.agent_id == agent.id
      assert job.agent_name == agent.name
    end

    test "when the job is started => error" do
      {:ok, job} = Support.Factories.Job.create(:started)

      agent = %Agent{
        id: @agent_id,
        ip_address: "1.2.3.4",
        ctrl_port: 80
      }

      assert {:error, :invalid_transition} = Job.start(job, agent)
    end

    test "when the job is finished => error" do
      {:ok, job} = Support.Factories.Job.create(:finished, %{result: "passed"})

      agent = %Agent{
        id: @agent_id,
        ip_address: "1.2.3.4",
        ctrl_port: 80
      }

      assert {:error, :invalid_transition} = Job.start(job, agent)
    end
  end

  describe ".stop" do
    test "it stops the job" do
      [
        Support.Factories.Job.create(:pending),
        Support.Factories.Job.create(:enqueued),
        Support.Factories.Job.create(:scheduled),
        Support.Factories.Job.create(:started)
      ]
      |> Enum.map(fn job -> elem(job, 1) end)
      |> Enum.each(fn job ->
        assert {:ok, job} = Job.stop(job)

        assert Job.stopped?(job)
        assert Job.finished?(job)
      end)
    end

    test "stops self-hosted job" do
      GrpcMock.stub(Support.FakeServers.SelfHosted, :stop_job, fn _, _ ->
        InternalApi.SelfHosted.StopJobResponse.new()
      end)

      [
        Support.Factories.Job.create(:pending, %{machine_type: "s1-job-test"}),
        Support.Factories.Job.create(:enqueued, %{machine_type: "s1-job-test"}),
        Support.Factories.Job.create(:scheduled, %{machine_type: "s1-job-test"}),
        Support.Factories.Job.create(:started, %{machine_type: "s1-job-test"})
      ]
      |> Enum.map(fn job -> elem(job, 1) end)
      |> Enum.each(fn job ->
        assert {:ok, job} = Job.stop(job)

        assert Job.stopped?(job)
        assert Job.finished?(job)
      end)
    end

    test "stops self-hosted job even if self hosted grpc endpoint fails" do
      GrpcMock.stub(Support.FakeServers.SelfHosted, :stop_job, fn _, _ ->
        raise "muahhahaaha"
      end)

      {:ok, job} = Support.Factories.Job.create(:started, %{machine_type: "s1-job-test"})

      assert {:ok, job} = Job.stop(job)

      assert Job.stopped?(job)
      assert Job.finished?(job)
    end

    test "tries to finish the task" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:scheduled, %{build_id: task.id})

      assert {:ok, job} = Job.stop(job)

      task = Zebra.Models.Task |> where([t], t.id == ^task.id) |> Zebra.LegacyRepo.one()

      assert Job.finished?(job)
      assert Job.stopped?(job)
      assert Zebra.Models.Task.finished?(task)
    end
  end

  describe ".finish" do
    test "when job is in any other state => transitions" do
      [
        Support.Factories.Job.create(:pending),
        Support.Factories.Job.create(:enqueued),
        Support.Factories.Job.create(:scheduled),
        Support.Factories.Job.create(:"waiting-for-agent")
      ]
      |> Enum.map(fn job -> elem(job, 1) end)
      |> Enum.each(fn job ->
        assert {:ok, job} = Job.finish(job, "passed")
        assert Job.finished?(job)
        assert Job.passed?(job)
        refute is_nil(job.finished_at)
      end)
    end

    test "when job is already finished => error" do
      {:ok, job} = Support.Factories.Job.create(:finished, %{result: "passed"})

      assert {:error, :invalid_transition} = Job.finish(job, "passed")
    end

    test "when the result is passed => finishes the job" do
      {:ok, job} = Support.Factories.Job.create(:started)

      assert {:ok, job} = Job.finish(job, "passed")

      assert Job.finished?(job)
      assert Job.passed?(job)
      refute is_nil(job.finished_at)
    end

    test "when the result is failed => finishes the job" do
      {:ok, job} = Support.Factories.Job.create(:started)

      assert {:ok, job} = Job.finish(job, "failed")

      assert Job.finished?(job)
      assert Job.failed?(job)
      refute is_nil(job.finished_at)
    end

    test "when the result is nil => error" do
      {:ok, job} = Support.Factories.Job.create(:started)

      assert {:error, :result_cant_be_nil} = Job.finish(job, nil)
    end

    test "tries to finish the task" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:started, %{build_id: task.id})

      assert {:ok, job} = Job.finish(job, "passed")

      task = Zebra.Models.Task |> where([t], t.id == ^task.id) |> Zebra.LegacyRepo.one()

      assert Job.finished?(job)
      assert Job.passed?(job)
      assert Zebra.Models.Task.finished?(task)
    end
  end

  describe ".detect_type" do
    test "when it is a pipeline job => pipeline_job" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:started, %{build_id: task.id})

      assert Job.detect_type(job) == :pipeline_job
    end

    test "when it is a debug job => debug_job" do
      {:ok, job} = Support.Factories.Job.create(:started, %{build_id: nil})
      {:ok, _} = Support.Factories.Debug.create_for_job(nil, job.id)

      assert Job.detect_type(job) == :debug_job
    end

    test "when it is a project level debug job => project_debug_job" do
      {:ok, job} = Support.Factories.Job.create(:started, %{build_id: nil})

      assert Job.detect_type(job) == :project_debug_job
    end
  end

  describe ".expired_job_ids" do
    test "returns expired jobs with artifact_store_id from project" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      past = DateTime.add(now, -3600, :second)

      project_id = Ecto.UUID.generate()
      artifact_store_id = Ecto.UUID.generate()

      Ecto.Adapters.SQL.query!(
        Zebra.LegacyRepo,
        "INSERT INTO projects (id, artifact_store_id) VALUES ($1, $2)",
        [Ecto.UUID.dump!(project_id), Ecto.UUID.dump!(artifact_store_id)]
      )

      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          project_id: project_id,
          expires_at: past
        })

      {:ok, result} = Job.expired_job_ids(10)

      job_result = Enum.find(result, fn {id, _, _, _} -> id == job.id end)
      assert job_result != nil

      {_id, _org_id, returned_project_id, returned_artifact_store_id} = job_result
      assert returned_project_id == project_id

      {:ok, expected_artifact_store_id} = Ecto.UUID.dump(artifact_store_id)
      assert returned_artifact_store_id == expected_artifact_store_id
    end

    test "returns nil artifact_store_id for jobs without matching project" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      past = DateTime.add(now, -3600, :second)
      orphan_project_id = Ecto.UUID.generate()

      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          project_id: orphan_project_id,
          expires_at: past
        })

      {:ok, result} = Job.expired_job_ids(10)

      job_result = Enum.find(result, fn {id, _, _, _} -> id == job.id end)
      assert job_result != nil

      {_id, _org_id, returned_project_id, returned_artifact_store_id} = job_result
      assert returned_project_id == orphan_project_id
      assert returned_artifact_store_id == nil
    end

    test "does not return jobs without expires_at" do
      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          expires_at: nil
        })

      {:ok, result} = Job.expired_job_ids(10)

      job_result = Enum.find(result, fn {id, _, _, _} -> id == job.id end)
      assert job_result == nil
    end

    test "does not return jobs with future expires_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      future = DateTime.add(now, 3600, :second)

      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          expires_at: future
        })

      {:ok, result} = Job.expired_job_ids(10)

      job_result = Enum.find(result, fn {id, _, _, _} -> id == job.id end)
      assert job_result == nil
    end
  end

  describe ".claim_and_delete_expired_jobs" do
    test "claims and deletes expired jobs in a transaction" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      past = DateTime.add(now, -3600, :second)

      project_id = Ecto.UUID.generate()
      artifact_store_id = Ecto.UUID.generate()

      Ecto.Adapters.SQL.query!(
        Zebra.LegacyRepo,
        "INSERT INTO projects (id, artifact_store_id) VALUES ($1, $2)",
        [Ecto.UUID.dump!(project_id), Ecto.UUID.dump!(artifact_store_id)]
      )

      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          project_id: project_id,
          expires_at: past
        })

      {:ok, _deleted_stop_requests, deleted_jobs} = Job.claim_and_delete_expired_jobs(10)

      assert deleted_jobs >= 1

      # Verify the job is actually deleted
      assert Zebra.LegacyRepo.get(Zebra.Models.Job, job.id) == nil
    end

    test "returns 0 counts when no expired jobs exist" do
      {:ok, deleted_stop_requests, deleted_jobs} = Job.claim_and_delete_expired_jobs(10)

      assert deleted_stop_requests == 0
      assert deleted_jobs == 0
    end

    test "does not claim jobs with future expires_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      future = DateTime.add(now, 3600, :second)

      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          expires_at: future
        })

      {:ok, _deleted_stop_requests, deleted_jobs} = Job.claim_and_delete_expired_jobs(10)

      assert deleted_jobs == 0

      # Verify the job still exists
      assert Zebra.LegacyRepo.get(Zebra.Models.Job, job.id) != nil
    end
  end
end
