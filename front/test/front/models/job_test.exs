defmodule Front.Models.JobTest do
  use ExUnit.Case

  alias Front.Models.Job
  alias InternalApi.ServerFarm.Job.JobSpec

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
  end

  describe ".create" do
    test "returns job details when all params are valid" do
      job_spec = valid_job_spec()

      params = %{
        user_id: "valid_response",
        project: %{id: UUID.uuid4(), organization_id: UUID.uuid4()},
        target_branch: "master",
        restricted_job: true
      }

      assert {:ok, job} = Job.create(job_spec, params)
      assert job.name == job_spec.job_name
      assert job.project_id == params.project.id
      assert job.machine_type == job_spec.agent.machine.type
    end

    test "returns error message when server responds with error" do
      job_spec = valid_job_spec()

      params = %{
        user_id: "error_response",
        project: %{id: UUID.uuid4(), organization_id: UUID.uuid4()},
        target_branch: "master",
        restricted_job: true
      }

      assert {:error, message} = Job.create(job_spec, params)
      assert message == "Invalid parameters."
    end

    test "returns generic error when server raises an exception" do
      job_spec = valid_job_spec()

      params = %{
        user_id: "raise_response",
        project: %{id: UUID.uuid4(), organization_id: UUID.uuid4()},
        target_branch: "master",
        restricted_job: true
      }

      assert {:error, :grpc_req_failed} = Job.create(job_spec, params)
    end
  end

  defp valid_job_spec do
    JobSpec.new(
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
    )
  end
end
