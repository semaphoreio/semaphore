defmodule Projecthub.Workers.ProjectInitTest do
  use Projecthub.DataCase
  alias Projecthub.Models.Project.StateMachine
  alias Projecthub.Events

  describe ".lock_and_process" do
    setup do
      stub_user_api()
      stub_cache_api()
      stub_artifact_api()
      stub_repohub_api()
      stub_rbac_api()
      stub_token_api()

      {:ok, project} = create_project_in_initializing_skip_state()
      {:ok, github_app_project} = create_project_in_initializing_skip_state("github_app")

      {:ok,
       %{
         project: project,
         github_app_project: github_app_project
       }}
    end

    test "it creates a deploy key for the project", %{project: project} do
      assert {:error, %{status: status}} =
               Projecthub.RepositoryHubClient.check_deploy_key(%{repository_id: project.repository.id})

      assert status == GRPC.Status.not_found()

      assert lock_and_process(project.id) == {:ok, true}

      assert {:ok, _} = Projecthub.RepositoryHubClient.check_deploy_key(%{repository_id: project.repository.id})
    end

    test "it creates a github post commit hook for the github app project", %{
      github_app_project: project
    } do
      assert {:error, %{status: 5}} =
               Projecthub.RepositoryHubClient.check_webhook(%{repository_id: project.repository.id})

      assert lock_and_process(project.id) == {:ok, true}

      assert {:ok, _} = Projecthub.RepositoryHubClient.check_webhook(%{repository_id: project.repository.id})
    end

    test "it creates a github post commit hook for the project", %{project: project} do
      assert {:error, %{status: 5}} =
               Projecthub.RepositoryHubClient.check_webhook(%{repository_id: project.repository.id})

      assert lock_and_process(project.id) == {:ok, true}

      assert {:ok, _} = Projecthub.RepositoryHubClient.check_webhook(%{repository_id: project.repository.id})
    end

    test "it transitions the project from 'initializing' to 'ready'", %{project: project} do
      assert reload(project).state == StateMachine.initializing_skip()

      assert lock_and_process(project.id) == {:ok, true}

      assert reload(project).state == StateMachine.ready()
    end

    test "it emits project created event", %{project: project} do
      with_mocks([
        {Events.ProjectCreated, [], [publish: fn _ -> {:ok, nil} end]}
      ]) do
        assert reload(project).state == StateMachine.initializing_skip()

        assert lock_and_process(project.id) == {:ok, true}

        assert reload(project).state == StateMachine.ready()

        assert_called(
          Events.ProjectCreated.publish(%{project_id: project.id, organization_id: project.organization_id})
        )
      end
    end

    test "it creates an artifact storage for the project", %{project: project} do
      assert reload(project).artifact_store_id == nil

      assert lock_and_process(project.id) == {:ok, true}

      refute reload(project).artifact_store_id == nil
    end

    test "it creates a cache storage for the project", %{project: project} do
      assert reload(project).cache_id == nil

      assert lock_and_process(project.id) == {:ok, true}

      refute reload(project).cache_id == nil
    end

    test "when connecting to github fails (unrecoverably) => it transitions to error state", %{
      project: project
    } do
      Support.FakeServices.RepositoryService.fail(:regenerate_webhook, project.repository.id)

      assert Projecthub.Workers.ProjectInit.lock_and_process(project.id) == {:ok, false}

      assert reload(project).state == StateMachine.error()

      assert reload(project).state_reason == "Error"
    end

    test "when connecting to cachehub succeeds, but artifacthub connection fails => it preserves the cache id",
         %{project: project} do
      assert reload(project).cache_id == nil
      assert reload(project).artifact_store_id == nil

      stub_artifact_api_with_broken_response()

      assert lock_and_process(project.id) == {:ok, false}

      refute reload(project).cache_id == nil
      assert reload(project).artifact_store_id == nil
      assert reload(project).state == StateMachine.initializing_skip()
    end

    test "when project has been initializing for 20 minutes => it moves the project to error state",
         %{project: project} do
      more_than_20_mins_ago = DateTime.to_unix(DateTime.utc_now()) - 22 * 60

      {:ok, project} =
        Projecthub.Models.Project.update_record(project, %{
          created_at: DateTime.from_unix!(more_than_20_mins_ago)
        })

      assert lock_and_process(project.id) == {:ok, false}

      assert reload(project).state == StateMachine.error()
      assert reload(project).state_reason == "Project initialization timeout."
    end
  end

  describe ".lock_and_process with new_project_onboarding feature enabled" do
    setup do
      stub_user_api()
      stub_cache_api()
      stub_artifact_api()
      stub_repohub_api()
      stub_rbac_api()
      stub_token_api()

      {:ok, project} = create_project_in_initializing_state()
      {:ok, github_app_project} = create_project_in_initializing_skip_state("github_app")

      FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
        availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 10)

        InternalApi.Feature.ListOrganizationFeaturesResponse.new(
          organization_features: [
            [feature: %{type: "max_projects_in_org"}, availability: availability],
            [feature: %{type: "new_project_onboarding"}, availability: availability]
          ]
        )
      end)

      on_exit(fn ->
        FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
          availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 10)

          InternalApi.Feature.ListOrganizationFeaturesResponse.new(
            organization_features: [
              [feature: %{type: "max_projects_in_org"}, availability: availability]
            ]
          )
        end)
      end)

      {:ok,
       %{
         project: project,
         github_app_project: github_app_project
       }}
    end

    test "it transitions the project from 'initializing' to 'onboarding'", %{project: project} do
      assert reload(project).state == StateMachine.initializing()

      assert lock_and_process(project.id) == {:ok, true}

      assert reload(project).state == StateMachine.onboarding()
    end

    test "it transitions the project from 'initializing_skip' to 'ready'", %{github_app_project: project} do
      assert reload(project).state == StateMachine.initializing_skip()

      assert lock_and_process(project.id) == {:ok, true}

      assert reload(project).state == StateMachine.ready()
    end
  end

  defp create_project_in_initializing_skip_state(integration_type \\ "github_oauth_token") do
    project_params = %{
      artifact_store_id: nil,
      cache_id: nil,
      state: StateMachine.initializing_skip()
    }

    repo_params = %{
      hook_id: nil,
      integration_type: integration_type
    }

    Support.Factories.Project.create_with_repo(project_params, repo_params)
  end

  defp create_project_in_initializing_state(integration_type \\ "github_oauth_token") do
    project_params = %{
      artifact_store_id: nil,
      cache_id: nil,
      state: StateMachine.initializing()
    }

    repo_params = %{
      hook_id: nil,
      integration_type: integration_type
    }

    Support.Factories.Project.create_with_repo(project_params, repo_params)
  end

  defp reload(project) do
    {:ok, project} = Projecthub.Models.Project.find(project.id)

    project
  end

  def stub_repohub_api do
    files_response =
      InternalApi.Repository.GetFilesResponse.new(
        files: [
          InternalApi.Repository.File.new(path: "Gemfile", content: "")
        ]
      )

    FunRegistry.set!(Support.FakeServices.Repohub, :get_files, files_response)
  end

  def stub_user_api do
    user_response =
      InternalApi.User.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        github_token: "yourtokencomeshere"
      )

    FunRegistry.set!(Support.FakeServices.UserService, :describe, user_response)
  end

  def stub_cache_api do
    cache_id = Ecto.UUID.generate()

    cache_response =
      InternalApi.Cache.CreateResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        cache_id: cache_id
      )

    FunRegistry.set!(Support.FakeServices.CacheService, :create, cache_response)
  end

  def stub_artifact_api do
    artifact_id = Ecto.UUID.generate()
    artifact = InternalApi.Artifacthub.Artifact.new(id: artifact_id)

    res = InternalApi.Artifacthub.CreateResponse.new(artifact: artifact)

    FunRegistry.set!(Support.FakeServices.ArtifactService, :create, res)
  end

  def stub_artifact_api_with_broken_response do
    FunRegistry.set!(Support.FakeServices.ArtifactService, :create, fn _, _ ->
      raise "I'm broken"
    end)
  end

  def stub_rbac_api do
    list_resp =
      InternalApi.RBAC.ListRolesResponse.new(
        roles: [
          InternalApi.RBAC.Role.new(
            id: Ecto.UUID.generate(),
            name: "Admin",
            org_id: Ecto.UUID.generate(),
            scope: InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
          )
        ]
      )

    FunRegistry.set!(Support.FakeServices.RbacService, :list_roles, list_resp)
    FunRegistry.set!(Support.FakeServices.RbacService, :assign_role, InternalApi.RBAC.AssignRoleResponse.new())
  end

  def stub_token_api do
    response = InternalApi.RepositoryIntegrator.GetTokenResponse.new(token: "foo")

    FunRegistry.set!(Support.FakeServices.RepositoryIntegratorService, :get_token, response)
  end

  def lock_and_process(project_id) do
    Projecthub.Workers.ProjectInit.lock_and_process(project_id)
  end
end
