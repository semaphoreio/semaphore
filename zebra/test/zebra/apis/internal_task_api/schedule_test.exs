defmodule Zebra.Apis.InternalTaskApi.ScheduleTest do
  use Zebra.DataCase

  alias Zebra.Apis.InternalTaskApi.Schedule

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
      org_id = "enabled_30"

      Cachex.clear(:zebra_cache)

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
      org_id = "enabled_30"

      Cachex.clear(:zebra_cache)

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
      assert @default_job_execution_time_limit == Schedule.configure_execution_time_limit(org_id, 0)
      assert @default_job_execution_time_limit == Schedule.configure_execution_time_limit(org_id, -5)
    end

    test "when org is not verified and feature is enabled => applies feature limit" do
      org_id = "enabled_30"

      Cachex.clear(:zebra_cache)

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
