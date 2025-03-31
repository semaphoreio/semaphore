defmodule Front.Models.CommitJobTest do
  use ExUnit.Case

  import Mock

  alias Front.Models.CommitJob
  alias InternalApi.Repository.File
  alias Front.Models.OrganizationSettings
  alias InternalApi.ServerFarm.Job.JobSpec
  alias InternalApi.Repository.CommitRequest.Change

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    project_stub = Support.Stubs.DB.first(:projects)
    project = Front.Models.Project.find(project_stub.id, project_stub.org_id)

    [project: project]
  end

  describe ".get_agent" do
    test "returns custom agent details if they are configured", %{project: project} do
      org = Support.Stubs.DB.find(:organizations, project.organization_id)

      Support.Stubs.Organization.put_settings(org, %{
        "custom_machine_type" => "f1-standard-2",
        "plan_machine_type" => "e2-standard-2",
        "custom_os_image" => "ubuntu2204",
        "plan_os_image" => "ubuntu2004"
      })

      assert {:ok, agent} = CommitJob.get_agent(project)
      assert agent.type == "f1-standard-2"
      assert agent.os_image == "ubuntu2204"
    end

    test "retruns plan-default agent details when there are no custom ones", %{project: project} do
      org = Support.Stubs.DB.find(:organizations, project.organization_id)

      Support.Stubs.Organization.put_settings(org, %{
        "custom_machine_type" => "",
        "plan_machine_type" => "e2-standard-2",
        "custom_os_image" => "",
        "plan_os_image" => "ubuntu2004"
      })

      assert {:ok, agent} = CommitJob.get_agent(project)
      assert agent.type == "e2-standard-2"
      assert agent.os_image == "ubuntu2004"

      Support.Stubs.Organization.put_settings(org, %{
        "plan_machine_type" => "e2-standard-2",
        "plan_os_image" => "ubuntu2004"
      })

      assert {:ok, agent} = CommitJob.get_agent(project)
      assert agent.type == "e2-standard-2"
      assert agent.os_image == "ubuntu2004"
    end

    test "returns error when agent is not configured", %{project: project} do
      assert {:error, :settings_without_agent_def} = CommitJob.get_agent(project)
    end

    test "returns error when server responds with error", %{project: project} do
      with_mock OrganizationSettings, fetch: fn _ -> {:error, "Internal error"} end do
        assert {:error, :fetch_agent, error} = CommitJob.get_agent(project)
        assert error == {:error, "Internal error"}
      end
    end
  end

  describe ".get_git_credentials" do
    test "returns valid credentials for all integration types" do
      project = %{
        id: UUID.uuid4(),
        organization_id: UUID.uuid4(),
        integration_type: :GITHUB_OAUTH_TOKEN,
        repo_owner: "semaphoreio",
        repo_name: "semaphore"
      }

      user_id = UUID.uuid4()
      assert {:ok, creds} = CommitJob.get_git_credentials(project, user_id)
      assert %{username: "x-oauth-token", token: "valid_token_value"} == creds

      project = %{project | integration_type: :GITHUB_APP}
      assert {:ok, creds} = CommitJob.get_git_credentials(project, user_id)
      assert %{username: "x-access-token", token: "valid_token_value"} == creds

      project = %{project | integration_type: :BITBUCKET}
      assert {:ok, creds} = CommitJob.get_git_credentials(project, user_id)
      assert %{username: "x-token-auth", token: "valid_token_value"} == creds

      project = %{project | integration_type: :GITLAB}
      assert {:ok, creds} = CommitJob.get_git_credentials(project, user_id)
      assert %{username: "oauth2", token: "valid_token_value"} == creds
    end

    test "returns error when server responds with error" do
      project = %{
        id: UUID.uuid4(),
        organization_id: UUID.uuid4(),
        integration_type: :GITHUB_OAUTH_TOKEN,
        repo_owner: "semaphoreio",
        repo_name: "semaphore"
      }

      user_id = "invalid_response"

      assert {:error, :token_from_repo_integrator, error} =
               CommitJob.get_git_credentials(project, user_id)

      assert {:error, %GRPC.RPCError{status: 3, message: "Invalid request."}} == error

      project = %{project | integration_type: :BITBUCKET}

      assert {:error, :token_from_user_svc, error} =
               CommitJob.get_git_credentials(project, user_id)

      assert {:error, %GRPC.RPCError{status: 3, message: "Invalid request."}} == error
    end
  end

  describe ".create_job_spec" do
    test "generates valid spec when all arguments are valid", %{project: project} do
      org = Support.Stubs.DB.find(:organizations, project.organization_id)

      Support.Stubs.Organization.put_settings(org, %{
        "plan_machine_type" => "e2-standard-2",
        "plan_os_image" => "ubuntu2004"
      })

      assert {:ok, agent} = CommitJob.get_agent(project)

      user_id = "valid_token"
      project2 = %{project | integration_type: :GITHUB_APP}
      assert {:ok, creds} = CommitJob.get_git_credentials(project2, user_id)

      params = %{
        user: %{name: "John Doe", email: "jdoe@example.com"},
        project: project,
        user_id: UUID.uuid4(),
        initial_branch: "master",
        target_branch: "master",
        commit_message: "Update Semaphore configuration",
        changes: [
          Change.new(
            action: Change.Action.value(:ADD_FILE),
            file: File.new(path: ".semaphore/deploy.yaml", content: "first line\nsecond line")
          ),
          Change.new(
            action: Change.Action.value(:MODIFY_FILE),
            file: File.new(path: ".semaphore/semaphore.yaml", content: "first line\nsecond line")
          ),
          Change.new(
            action: Change.Action.value(:DELETE_FILE),
            file: File.new(path: ".semaphore/staging.yaml", content: "")
          )
        ]
      }

      expected_spec = get_expected_spec("master")

      assert {:ok, spec} = CommitJob.create_job_spec(agent, creds, params)
      assert expected_spec == spec

      expected_spec = get_expected_spec("new-branch")
      params = %{params | target_branch: "new-branch"}
      assert {:ok, spec} = CommitJob.create_job_spec(agent, creds, params)
      assert expected_spec == spec
    end
  end

  defp get_expected_spec(target_branch) do
    %JobSpec{
      job_name: "Commiting changes from workflow editor to branch #{target_branch}",
      agent: %JobSpec.Agent{
        machine: %JobSpec.Agent.Machine{
          os_image: "ubuntu2004",
          type: "e2-standard-2"
        },
        containers: [],
        image_pull_secrets: []
      },
      secrets: [],
      env_vars: [],
      files: [
        %JobSpec.File{
          path: ".workflow_editor/git_username.txt",
          content: Base.encode64("x-access-token")
        },
        %JobSpec.File{
          path: ".workflow_editor/git_password.txt",
          content: Base.encode64("valid_token_value")
        },
        %JobSpec.File{
          path: ".changed_files/.semaphore/deploy.yaml",
          content: Base.encode64("first line\nsecond line")
        },
        %JobSpec.File{
          path: ".changed_files/.semaphore/semaphore.yaml",
          content: Base.encode64("first line\nsecond line")
        }
      ],
      commands:
        [
          "export GIT_USERNAME=$(cat .workflow_editor/git_username.txt)",
          "export GIT_PASSWORD=$(cat .workflow_editor/git_password.txt)",
          "export GIT_REPO_URL=\"${SEMAPHORE_GIT_URL/://}\"",
          "export GIT_REPO_URL=\"${GIT_REPO_URL/git@/https:\/\/$GIT_USERNAME:$GIT_PASSWORD@}\"",
          "export SEMAPHORE_GIT_BRANCH=master",
          "checkout",
          "git checkout -b new-branch",
          "mkdir -p .semaphore",
          "mv ../.changed_files/.semaphore/deploy.yaml ./.semaphore/deploy.yaml",
          "mkdir -p .semaphore",
          "mv ../.changed_files/.semaphore/semaphore.yaml ./.semaphore/semaphore.yaml",
          "rm .semaphore/staging.yaml || true",
          "git config --global user.name John Doe",
          "git config --global user.email jdoe@example.com",
          "git add .",
          "git commit -m \"Update Semaphore configuration\"",
          "git push $GIT_REPO_URL HEAD",
          "git rev-parse HEAD > commit_sha.val",
          "artifact push job commit_sha.val -d .workflow_editor/commit_sha.val"
        ]
        |> drop_branch_switching?(target_branch),
      epilogue_always_commands: [],
      epilogue_on_pass_commands: [],
      epilogue_on_fail_commands: [],
      priority: 95,
      execution_time_limit: 10
    }
  end

  defp drop_branch_switching?(list, "master") do
    list |> Enum.filter(fn x -> x != "git checkout -b new-branch" end)
  end

  defp drop_branch_switching?(list, _), do: list
end
