defmodule Zebra.Apis.InternalTaskApi.ScheduleTest do
  use Zebra.DataCase

  alias Zebra.Apis.InternalTaskApi.Schedule
  alias Zebra.LegacyRepo, as: Repo
  alias Support.Factories

  # in seconds
  @default_job_execution_time_limit 24 * 60 * 60

  describe ".schedule" do
    test "it creates task with jobs" do
      token = Ecto.UUID.generate()
      req = construct_example_schedule_request(token)

      assert {:ok, task} = Schedule.schedule(req)

      task = Zebra.LegacyRepo.preload(task, [:jobs])

      assert task.ppl_id == req.ppl_id
      assert task.hook_id == req.hook_id
      assert task.workflow_id == req.wf_id
      assert task.fail_fast_strategy == "stop"

      assert Enum.count(task.jobs) == 2

      first_job = Enum.at(task.jobs, 0)
      second_job = Enum.at(task.jobs, 1)

      assert first_job.name == "Papa"
      assert second_job.name == "Papa2"

      assert first_job.project_id == req.project_id
      assert second_job.project_id == req.project_id

      assert first_job.repository_id == req.repository_id
      assert second_job.repository_id == req.repository_id

      assert first_job.organization_id == req.org_id
      assert second_job.organization_id == req.org_id

      assert first_job.organization_id == req.org_id
      assert second_job.organization_id == req.org_id

      assert first_job.build_id == task.id
      assert second_job.build_id == task.id

      assert first_job.priority == 75
      assert second_job.priority == 50

      # this is in seconds (in request it is in minutes)
      assert first_job.execution_time_limit == 5 * 60
      assert second_job.execution_time_limit == 24 * 60 * 60

      assert first_job.spec == %{
               "agent" => %{
                 "containers" => [
                   %{
                     "command" => "psql --serve",
                     "env_vars" => [
                       %{
                         "name" => "A",
                         "value" => "B"
                       }
                     ],
                     "image" => "postgres:9.6",
                     "name" => "main",
                     "secrets" => [
                       %{"name" => "A"}
                     ]
                   }
                 ],
                 "image_pull_secrets" => [%{"name" => "A"}],
                 "machine" => %{
                   "os_image" => "ubuntu1804",
                   "type" => "e1-standard-2"
                 }
               },
               "commands" => ["echo 'prologue'", "echo 'cmd'"],
               "env_vars" => [%{"name" => "A", "value" => "B"}],
               "epilogue_commands" => [],
               "epilogue_always_commands" => ["echo 'epilogue'"],
               "epilogue_on_pass_commands" => ["echo 'epilogue pass'"],
               "epilogue_on_fail_commands" => ["echo 'epilogue fail'"],
               "files" => [],
               "project_id" => req.project_id,
               "secrets" => [%{"name" => "A"}]
             }

      assert second_job.spec == %{
               "agent" => %{
                 "containers" => [
                   %{
                     "command" => "psql --serve",
                     "env_vars" => [
                       %{
                         "name" => "A",
                         "value" => "B"
                       }
                     ],
                     "image" => "postgres:9.6",
                     "name" => "main",
                     "secrets" => [
                       %{"name" => "A"}
                     ]
                   }
                 ],
                 "image_pull_secrets" => [%{"name" => "A"}],
                 "machine" => %{
                   "os_image" => "ubuntu1804",
                   "type" => "e1-standard-2"
                 }
               },
               "commands" => ["echo 'prologue'", "echo 'cmd'"],
               "env_vars" => [%{"name" => "B", "value" => "C"}],
               "epilogue_commands" => [],
               "epilogue_always_commands" => ["echo 'epilogue'"],
               "epilogue_on_pass_commands" => ["echo 'epilogue pass'"],
               "epilogue_on_fail_commands" => ["echo 'epilogue fail'"],
               "files" => [],
               "project_id" => req.project_id,
               "secrets" => [%{"name" => "koi"}]
             }
    end

    test "second time scheduling with the same token => returns same task" do
      token = Ecto.UUID.generate()
      req = construct_example_schedule_request(token)

      assert {:ok, task1} = Schedule.schedule(req)
      assert {:ok, task2} = Schedule.schedule(req)

      assert task1.id == task2.id
    end
  end

  describe ".schedule with job-level lightweight copies" do
    test "a member marker mints a copy row and does not schedule execution" do
      {orig_task, member} = original_with_passed_job()

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("copied", member.id)]
        )

      assert {:ok, task} = Schedule.schedule(req)
      task = Repo.preload(task, [:jobs])

      assert [copy] = task.jobs
      assert copy.original_job_id == member.id
      assert copy.aasm_state == "finished"
      assert copy.result == "passed"
      assert copy.build_id == task.id
    end

    test "mixes run and copy jobs under one task, preserving each job's index" do
      {orig_task, member} = original_with_passed_job(%{index: 5})

      req =
        copy_request(orig_task,
          jobs: [run_job_spec("run0"), copy_job_spec("copy1", member.id)]
        )

      assert {:ok, task} = Schedule.schedule(req)
      task = Repo.preload(task, [:jobs])

      run = Enum.find(task.jobs, fn j -> j.name == "run0" end)
      copy = Enum.find(task.jobs, fn j -> j.original_job_id == member.id end)

      assert run.aasm_state == "pending"
      assert is_nil(run.original_job_id)
      assert run.index == 0

      assert copy.aasm_state == "finished"
      assert copy.result == "passed"
      # copies carry the original job's index, not the request position
      assert copy.index == 5
    end

    test "markers present but original_task_id empty => invalid_argument" do
      req =
        copy_request(nil,
          jobs: [copy_job_spec("copy", Ecto.UUID.generate())],
          original_task_id: ""
        )

      assert {:error, :invalid_argument, _msg} = Schedule.schedule(req)
      assert {:error, :not_found} = Schedule.find_already_scheduled_task(req)
    end

    test "original_task_id referencing a nonexistent task => invalid_argument" do
      req =
        copy_request(nil,
          jobs: [copy_job_spec("copy", Ecto.UUID.generate())],
          original_task_id: Ecto.UUID.generate()
        )

      assert {:error, :invalid_argument, _msg} = Schedule.schedule(req)
    end

    test "original_task_id that is not a valid UUID => invalid_argument" do
      req =
        copy_request(nil,
          jobs: [copy_job_spec("copy", Ecto.UUID.generate())],
          original_task_id: "not-a-uuid"
        )

      assert {:error, :invalid_argument, msg} = Schedule.schedule(req)
      assert msg =~ "not a valid UUID"
    end

    test "marker that is not a valid UUID => invalid_argument" do
      {orig_task, _member} = original_with_passed_job()

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("copy", "not-a-uuid")]
        )

      assert {:error, :invalid_argument, msg} = Schedule.schedule(req)
      assert msg =~ "not a valid UUID"
      assert {:error, :not_found} = Schedule.find_already_scheduled_task(req)
    end

    test "original_task_id in a different workflow => invalid_argument" do
      {orig_task, member} = original_with_passed_job()

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("copy", member.id)],
          wf_id: Ecto.UUID.generate()
        )

      assert {:error, :invalid_argument, _msg} = Schedule.schedule(req)
    end

    test "marker whose job belongs to a DIFFERENT task => invalid_argument (cross-membership forge)" do
      {orig_task, _member} = original_with_passed_job()
      {:ok, other_task} = Factories.Task.create()

      {:ok, foreign} =
        Factories.Job.create(:finished, %{
          build_id: other_task.id,
          result: "passed"
        })

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("copy", foreign.id)]
        )

      assert {:error, :invalid_argument, _msg} = Schedule.schedule(req)
      # nothing was created
      assert {:error, :not_found} = Schedule.find_already_scheduled_task(req)
    end

    test "marker resolving to no row anywhere degrades to running the job" do
      {orig_task, _member} = original_with_passed_job()

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("vanished", Ecto.UUID.generate())]
        )

      assert {:ok, task} = Schedule.schedule(req)
      task = Repo.preload(task, [:jobs])

      assert [job] = task.jobs
      assert job.aasm_state == "pending"
      assert is_nil(job.original_job_id)
    end

    test "member source that is not passed degrades to running the job" do
      {:ok, orig_task} = Factories.Task.create()

      {:ok, member} =
        Factories.Job.create(:finished, %{
          build_id: orig_task.id,
          result: "failed"
        })

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("not-passed", member.id)]
        )

      assert {:ok, task} = Schedule.schedule(req)
      task = Repo.preload(task, [:jobs])

      assert [job] = task.jobs
      assert job.aasm_state == "pending"
      assert is_nil(job.original_job_id)
    end

    test "member source with nil finished_at degrades to running the job" do
      {:ok, orig_task} = Factories.Task.create()

      {:ok, member} =
        Factories.Job.create(:finished, %{
          build_id: orig_task.id,
          result: "passed",
          finished_at: nil
        })

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("no-finish", member.id)]
        )

      assert {:ok, task} = Schedule.schedule(req)
      task = Repo.preload(task, [:jobs])

      assert [job] = task.jobs
      assert job.aasm_state == "pending"
    end

    test "member source whose tenant differs from the request => invalid_argument" do
      {orig_task, member} = original_with_passed_job()

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("copy", member.id)],
          org_id: Ecto.UUID.generate()
        )

      assert {:error, :invalid_argument, _msg} = Schedule.schedule(req)
    end

    test "a copy row is born finished and is never picked up by the pending scheduler (D-16)" do
      {orig_task, member} = original_with_passed_job()

      req =
        copy_request(orig_task,
          jobs: [run_job_spec("run0"), copy_job_spec("copy1", member.id)]
        )

      assert {:ok, task} = Schedule.schedule(req)
      task = Repo.preload(task, [:jobs])

      copy = Enum.find(task.jobs, fn j -> j.original_job_id == member.id end)
      run = Enum.find(task.jobs, fn j -> j.name == "run0" end)

      pending_ids =
        Zebra.Models.Job
        |> where([j], j.build_id == ^task.id and j.aasm_state == "pending")
        |> select([j], j.id)
        |> Repo.all()

      # JobRequestFactory (and its lifecycle-event publishing) only ever sees
      # pending jobs; a born-finished copy is structurally excluded.
      refute copy.id in pending_ids
      assert run.id in pending_ids
    end

    test "onprem_metrics is emitted for run jobs but not for copies (finding 12)" do
      {orig_task, member} = original_with_passed_job()

      req =
        copy_request(orig_task,
          jobs: [run_job_spec("run0"), copy_job_spec("copy1", member.id)]
        )

      with_mocks [
        {Zebra, [:passthrough], [on_prem?: fn -> true end]},
        {Watchman, [:passthrough], [increment: fn _ -> :ok end]}
      ] do
        assert {:ok, _task} = Schedule.schedule(req)

        assert_called_exactly(
          Watchman.increment(external: {"new_jobs", [agent: "e1-standard-2"]}),
          1
        )
      end
    end

    test "a duplicate build_request_id surfaces as a changeset error, not a raised ConstraintError" do
      token = Ecto.UUID.generate()
      {:ok, _first} = Factories.Task.create(%{build_request_id: token})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Zebra.Models.Task.create(
                 version: "v0.0",
                 build_request_id: token,
                 hook_id: Ecto.UUID.generate(),
                 workflow_id: Ecto.UUID.generate(),
                 ppl_id: Ecto.UUID.generate()
               )

      assert Keyword.has_key?(changeset.errors, :build_request_id)
    end

    test "losing a concurrent race on request_token returns the existing task (idempotency)" do
      token = Ecto.UUID.generate()
      {:ok, winner} = Factories.Task.create(%{build_request_id: token})

      req = construct_example_schedule_request(token)

      # create_task bypasses the request_token pre-read, exercising the
      # unique-constraint + re-read path directly.
      assert {:ok, task} = Schedule.create_task(req)
      assert task.id == winner.id

      count =
        Zebra.Models.Task
        |> where([t], t.build_request_id == ^token)
        |> Repo.aggregate(:count)

      assert count == 1
    end

    test "an all-copy task is finished immediately after schedule" do
      {orig_task, m1} = original_with_passed_job(%{index: 0})

      {:ok, m2} =
        Factories.Job.create(:finished, %{
          build_id: orig_task.id,
          result: "passed",
          index: 1
        })

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("c1", m1.id), copy_job_spec("c2", m2.id)]
        )

      assert {:ok, task} = Schedule.schedule(req)

      # finished synchronously, not left waiting on the periodic poller
      assert task.result == "passed"
    end

    test "D-05: a marker pointing at a member that is itself a copy flattens to the terminal original" do
      terminal = Ecto.UUID.generate()
      {orig_task, member} = original_with_passed_job(%{original_job_id: terminal})

      req =
        copy_request(orig_task,
          jobs: [copy_job_spec("chained", member.id)]
        )

      assert {:ok, task} = Schedule.schedule(req)
      task = Repo.preload(task, [:jobs])

      assert [copy] = task.jobs
      assert copy.original_job_id == terminal
    end
  end

  describe ".encode_fail_fast_strategy" do
    test "it converts to database friendly strings" do
      stop = InternalApi.Task.ScheduleRequest.FailFast.value(:STOP)
      cancel = InternalApi.Task.ScheduleRequest.FailFast.value(:CANCEL)
      none = InternalApi.Task.ScheduleRequest.FailFast.value(:NONE)

      assert Schedule.encode_fail_fast_strategy(stop) == "stop"
      assert Schedule.encode_fail_fast_strategy(cancel) == "cancel"
      assert Schedule.encode_fail_fast_strategy(none) == nil
    end
  end

  describe ".configure_execution_time_limit" do
    setup do
      Cachex.clear(:zebra_cache)

      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "test-org",
              verified: false
            )
        )
      end)

      :ok
    end

    test "when feature is disabled and limit from request is valid => returns limit from request in seconds" do
      org_id = UUID.uuid4()

      assert 180 * 60 == Schedule.configure_execution_time_limit(org_id, 180)
    end

    test "when feature is disabled and limit from request is invalid => returns default limit in seconds" do
      org_id = UUID.uuid4()

      # if requested limit <= 0 -> configure it to default one
      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, 0)

      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, -5)

      # if requested limit >= max time limit -> configure it to default one
      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, 48 * 60)
    end

    test "when feature is enabled and limit from request is valid => returns limit from request in seconds" do
      org_id = "enabled_30"

      # requested limit is less then feature limit of 30 minutes
      assert 15 * 60 == Schedule.configure_execution_time_limit(org_id, 15)
    end

    test "when feature is enabled, limit from request is invalid, and feature limit >= default limit  => returns default limit" do
      org_id = "enabled_48h"

      # if requested limit <= 0 and feature limit >= max limit -> configure it to default one
      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, 0)

      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, -5)

      # if requested limit > feature limit and feature limit >= max limit -> configure it to default one
      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, 72 * 60)
    end

    test "when feature is enabled, limit from request is invalid, and feature limit < default limit  => returns feature limit" do
      org_id = "enabled_30"

      # if requested limit <= 0 and feature limit < max limit -> configure it to feature limit
      assert 30 * 60 == Schedule.configure_execution_time_limit(org_id, 0)
      assert 30 * 60 == Schedule.configure_execution_time_limit(org_id, -5)

      # if requested limit > feature limit and feature limit < max limit -> configure it to feature limit
      assert 30 * 60 == Schedule.configure_execution_time_limit(org_id, 180)
    end

    test "when org is verified and feature is enabled => bypasses feature limit and uses requested limit" do
      org_id = "enabled_30_verified"

      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "verified-org",
              verified: true
            )
        )
      end)

      # requested limit of 180 minutes would normally be capped to 30 minutes by feature flag
      # but since org is verified, it should return the requested limit
      assert 180 * 60 == Schedule.configure_execution_time_limit(org_id, 180)
    end

    test "when org is verified and feature is enabled with invalid request => returns default limit" do
      org_id = "enabled_30_verified"

      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "verified-org",
              verified: true
            )
        )
      end)

      # invalid request (0 or negative) should return default limit (24h)
      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, 0)

      assert @default_job_execution_time_limit ==
               Schedule.configure_execution_time_limit(org_id, -5)
    end

    test "when org is not verified and feature is enabled => applies feature limit" do
      org_id = "enabled_30_unverified"

      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "unverified-org",
              verified: false
            )
        )
      end)

      # requested limit of 180 minutes should be capped to 30 minutes by feature flag
      assert 30 * 60 == Schedule.configure_execution_time_limit(org_id, 180)
    end
  end

  #
  # Utils
  #

  defp example_agent do
    alias InternalApi.Task.ScheduleRequest, as: R

    R.Job.Agent.new(
      machine:
        R.Job.Agent.Machine.new(
          type: "e1-standard-2",
          os_image: "ubuntu1804"
        )
    )
  end

  defp run_job_spec(name) do
    alias InternalApi.Task.ScheduleRequest, as: R

    R.Job.new(
      name: name,
      agent: example_agent(),
      commands: ["echo 'cmd'"]
    )
  end

  defp copy_job_spec(name, original_job_id) do
    alias InternalApi.Task.ScheduleRequest, as: R

    R.Job.new(
      name: name,
      agent: example_agent(),
      commands: ["echo 'cmd'"],
      original_job_id: original_job_id
    )
  end

  # Creates an original finished+passed job on a fresh original task.
  # The member inherits the shared factory org/project so a copy_request/2
  # built from the same task validates as an exact member of the same tenant.
  defp original_with_passed_job(overrides \\ %{}) do
    {:ok, orig_task} = Factories.Task.create()

    {:ok, member} =
      Factories.Job.create(
        :finished,
        Map.merge(
          %{
            build_id: orig_task.id,
            result: "passed",
            organization_id: Factories.Job.org_id(),
            project_id: Factories.Job.project_id()
          },
          overrides
        )
      )

    {orig_task, member}
  end

  # Builds a ScheduleRequest wired to copy from `orig_task`: workflow, org and
  # project default to the original's tenant so the exact-membership validation
  # passes unless a test overrides one to exercise a rejection path.
  defp copy_request(orig_task, opts) do
    alias InternalApi.Task.ScheduleRequest, as: R

    defaults = [
      jobs: [],
      request_token: Ecto.UUID.generate(),
      ppl_id: Ecto.UUID.generate(),
      hook_id: Ecto.UUID.generate(),
      wf_id: if(orig_task, do: orig_task.workflow_id, else: Ecto.UUID.generate()),
      project_id: Factories.Job.project_id(),
      repository_id: Ecto.UUID.generate(),
      org_id: Factories.Job.org_id(),
      original_task_id: if(orig_task, do: orig_task.id, else: ""),
      fail_fast: R.FailFast.value(:NONE)
    ]

    R.new(Keyword.merge(defaults, opts))
  end

  def construct_example_schedule_request(token) do
    alias InternalApi.Task.ScheduleRequest, as: R

    agent =
      R.Job.Agent.new(
        machine:
          R.Job.Agent.Machine.new(
            type: "e1-standard-2",
            os_image: "ubuntu1804"
          ),
        containers: [
          R.Job.Agent.Container.new(
            name: "main",
            command: "psql --serve",
            image: "postgres:9.6",
            env_vars: [
              R.Job.EnvVar.new(name: "A", value: "B")
            ],
            secrets: [
              R.Job.Secret.new(name: "A")
            ]
          )
        ],
        image_pull_secrets: [
          R.Job.Agent.ImagePullSecret.new(name: "A")
        ]
      )

    job1 =
      R.Job.new(
        name: "Papa",
        agent: agent,
        priority: 75,
        execution_time_limit: 5,
        env_vars: [
          R.Job.EnvVar.new(name: "A", value: "B")
        ],
        secrets: [
          R.Job.Secret.new(name: "A")
        ],
        prologue_commands: [
          "echo 'prologue'"
        ],
        commands: [
          "echo 'cmd'"
        ],
        epilogue_always_cmds: [
          "echo 'epilogue'"
        ],
        epilogue_on_pass_cmds: [
          "echo 'epilogue pass'"
        ],
        epilogue_on_fail_cmds: [
          "echo 'epilogue fail'"
        ]
      )

    job2 =
      R.Job.new(
        name: "Papa2",
        agent: agent,
        # values out of range [0, 100] are replaced with default=50
        priority: 145,
        # should be replaced with max value which is 24*60 minutes
        execution_time_limit: 48 * 60,
        env_vars: [
          R.Job.EnvVar.new(name: "B", value: "C")
        ],
        secrets: [
          R.Job.Secret.new(name: "koi")
        ],
        prologue_commands: [
          "echo 'prologue'"
        ],
        commands: [
          "echo 'cmd'"
        ],
        epilogue_always_cmds: [
          "echo 'epilogue'"
        ],
        epilogue_on_pass_cmds: [
          "echo 'epilogue pass'"
        ],
        epilogue_on_fail_cmds: [
          "echo 'epilogue fail'"
        ]
      )

    R.new(
      jobs: [job1, job2],
      request_token: token,
      ppl_id: Ecto.UUID.generate(),
      hook_id: Ecto.UUID.generate(),
      wf_id: Ecto.UUID.generate(),
      project_id: Ecto.UUID.generate(),
      repository_id: Ecto.UUID.generate(),
      org_id: Ecto.UUID.generate(),
      fail_fast: R.FailFast.value(:STOP)
    )
  end
end
