defmodule Projecthub.Models.ProjectTest do
  require Logger

  use Projecthub.DataCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias Projecthub.Models.Project
  alias Projecthub.Models.User
  alias Projecthub.Models.Organization
  alias Projecthub.Models.Repository
  alias Projecthub.Events
  alias Projecthub.Schedulers

  @request_id Ecto.UUID.generate()

  setup do
    cache_id = Ecto.UUID.generate()

    cache_response =
      InternalApi.Cache.CreateResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        cache_id: cache_id
      )

    FunRegistry.set!(Support.FakeServices.CacheService, :create, cache_response)

    artifact_id = Ecto.UUID.generate()

    artifact_response =
      InternalApi.Artifacthub.CreateResponse.new(artifact: InternalApi.Artifacthub.Artifact.new(id: artifact_id))

    FunRegistry.set!(
      Support.FakeServices.ArtifactService,
      :create,
      artifact_response
    )

    FunRegistry.set!(
      Support.FakeServices.ArtifactService,
      :destroy,
      InternalApi.Artifacthub.DestroyResponse.new()
    )

    user_response =
      InternalApi.User.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        github_token: Support.FakeServices.github_token()
      )

    FunRegistry.set!(Support.FakeServices.UserService, :describe, user_response)

    list_response =
      InternalApi.PeriodicScheduler.ListResponse.new(
        status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
        periodics: []
      )

    FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :list, list_response)

    FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
      availability = InternalApi.Feature.Availability.new(state: :HIDDEN, quantity: 0)

      InternalApi.Feature.ListOrganizationFeaturesResponse.new(
        organization_features: [
          [feature: %{type: "new_project_onboarding"}, availability: availability]
        ]
      )
    end)
  end

  describe ".id_is_uuid?" do
    test "returns false for appsignal-server" do
      assert Project.id_is_uuid?("appsignal-server") == false
    end

    test "returns true for any UUID format string" do
      assert Project.id_is_uuid?("fe312f11-beec-4700-a553-8a12873f1c36") == true
    end
  end

  describe ".create" do
    test "it should create a project record" do
      request_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      user = %User{id: user_id}
      org = %Organization{id: org_id}

      integration_type = InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)

      project_spec = %{
        name: "semaphore",
        id: "",
        owner_id: "",
        org_id: "",
        description: ""
      }

      repo_details = %{
        url: "https://github.com/organization/repo_name.git",
        pipeline_file: ".semaphore/semaphore.yml",
        commit_status: %{
          "pipeline_files" => [
            %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
          ]
        },
        whitelist: %{
          "branches" => ["master", "/feature-*/"],
          "tags" => []
        },
        integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
      }

      {:ok, project} = Project.create(request_id, user, org, project_spec, repo_details, integration_type)

      assert project.id != ""
      assert project.state == "initializing_skip"
      assert project.name == "semaphore"
      assert project.description == ""
      assert project.created_at
      assert project.updated_at
      assert project.organization_id == org_id
      assert project.creator_id == user_id
      assert project.build_pr == false
      assert project.build_tag == true
      assert project.build_branch == true
      assert project.build_forked_pr == false
      assert project.build_draft_pr == true
    end

    test "it should create a repo record" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      user = %User{id: user_id}
      org = %Organization{id: org_id}

      project_spec = %{
        name: "semaphore",
        id: "",
        owner_id: "",
        org_id: "",
        description: ""
      }

      repo_details = %{
        url: "https://github.com/organization/repo_name.git",
        pipeline_file: ".semaphore/semaphore.yml",
        commit_status: %{
          "pipeline_files" => [
            %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
          ]
        },
        whitelist: %{
          "branches" => ["master", "/feature-*/"],
          "tags" => []
        },
        integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
      }

      {:ok, project} =
        Project.create(
          @request_id,
          user,
          org,
          project_spec,
          repo_details,
          repo_details.integration_type
        )

      {:ok, repo} = Repository.find_for_project(project.id)

      assert repo.private == false
      assert repo.owner == "owner"
      assert repo.name == "project-#{repo.id}"
      assert repo.url == "https://github.com/organization/repo_name.git"
      assert repo.pipeline_file == ".semaphore/semaphore.yml"
    end

    test "it emits a project created event" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      user = %User{id: user_id}
      org = %Organization{id: org_id}

      project_spec = %{
        name: "semaphore",
        owner_id: user_id,
        org_id: org_id,
        description: ""
      }

      repo_details = %{
        pipeline_file: ".semaphore/semaphore.yml",
        url: "https://github.com/semaphoreci/project.git",
        commit_status: %{
          "pipeline_files" => [
            %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
          ]
        },
        whitelist: %{
          "branches" => ["master", "/feature-*/"],
          "tags" => []
        },
        integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
      }

      {:ok, _project} =
        Project.create(
          @request_id,
          user,
          org,
          project_spec,
          repo_details,
          repo_details.integration_type
        )
    end
  end

  describe ".create with feature" do
    setup do
      FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
        availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 1)

        InternalApi.Feature.ListOrganizationFeaturesResponse.new(
          organization_features: [
            [feature: %{type: "new_project_onboarding"}, availability: availability]
          ]
        )
      end)
    end

    test "it creates a project in initializing state" do
      request_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      user = %User{id: user_id}
      org = %Organization{id: org_id}

      integration_type = InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)

      project_spec = %{
        name: "semaphore",
        id: "",
        owner_id: "",
        org_id: "",
        description: ""
      }

      repo_details = %{
        url: "https://github.com/organization/repo_name.git",
        pipeline_file: ".semaphore/semaphore.yml",
        commit_status: %{
          "pipeline_files" => [
            %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
          ]
        },
        whitelist: %{
          "branches" => ["master", "/feature-*/"],
          "tags" => []
        },
        integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
      }

      {:ok, project} = Project.create(request_id, user, org, project_spec, repo_details, integration_type)

      assert project.id != ""
      assert project.state == "initializing"
    end
  end

  describe ".update" do
    test "when project and repo are changed => updates the project and repo, sets up the new key and hook" do
      creator_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          name: "awesome_project",
          creator_id: creator_id,
          organization_id: org_id,
          description: "Just an awesome project"
        })

      project_params = %{
        name: "semaphore",
        id: project.id,
        org_id: org_id,
        description: "A repo for testing SemaphoreCI features",
        build_draft_pr: false,
        state: "ready"
      }

      repo_params = %{
        url: "git@github.com:semaforko-vcr-tester/hello-world-2.git"
      }

      schedulers = []
      tasks = []

      {:ok, updated_project} =
        Project.update(
          project,
          project_params,
          repo_params,
          schedulers,
          tasks,
          "requester_id"
        )

      assert updated_project.id == project.id
      assert updated_project.name == "semaphore"
      assert updated_project.creator_id == creator_id
      assert updated_project.organization_id == project.organization_id
      assert updated_project.description == "A repo for testing SemaphoreCI features"
      assert updated_project.build_draft_pr == false
    end

    test "it emits a project created event" do
      creator_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          name: "awesome_project",
          creator_id: creator_id,
          organization_id: org_id,
          description: "Just an awesome project"
        })

      project_params = %{
        name: project.name,
        id: project.id,
        owner_id: "",
        org_id: project.organization_id,
        description: project.description
      }

      repo_params = %{
        url: "git@github.com:organization/awesome_project.git"
      }

      schedulers = []
      tasks = []

      with_mocks([
        {Events.ProjectUpdated, [], [publish: fn _ -> {:ok, nil} end]}
      ]) do
        {:ok, updated_project} =
          Project.update(
            project,
            project_params,
            repo_params,
            schedulers,
            tasks,
            "requester_id"
          )

        assert_called(Events.ProjectUpdated.publish(updated_project))
      end
    end

    test "it updates schedulers when tasks are empty" do
      creator_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          name: "awesome_project",
          creator_id: creator_id,
          organization_id: org_id,
          description: "Just an awesome project"
        })

      _new_owner_id = Ecto.UUID.generate()

      project_params = %{
        name: project.name,
        id: project.id,
        owner_id: "",
        org_id: project.organization_id,
        description: project.description
      }

      repo_params = %{
        url: "git@github.com:organization/awesome_project.git"
      }

      schedulers = []
      tasks = []

      with_mock Schedulers, update: fn _p, _s, _r -> {:ok, nil} end do
        {:ok, _updated_project} =
          Project.update(
            project,
            project_params,
            repo_params,
            schedulers,
            tasks,
            "requester_id"
          )

        assert_called(Schedulers.update(:_, schedulers, "requester_id"))
      end
    end

    test "when the org id is attempted to change => doesn't change" do
      creator_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          name: "awesome_project",
          creator_id: creator_id,
          organization_id: org_id,
          description: "Just an awesome project"
        })

      new_org_id = Ecto.UUID.generate()

      project_params = %{
        name: "semaphore",
        id: project.id,
        owner_id: creator_id,
        org_id: new_org_id,
        description: "Even more awesome project"
      }

      repo_params = %{
        url: "git@github.com:semaforko-vcr-tester/hello-world.git"
      }

      schedulers = []
      tasks = []

      {:ok, updated_project} =
        Project.update(
          project,
          project_params,
          repo_params,
          schedulers,
          tasks,
          "requester_id"
        )

      assert updated_project.organization_id == org_id
    end

    test "when the creator id is attempted to change => doesn't change" do
      creator_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          name: "awesome_project",
          creator_id: creator_id,
          organization_id: org_id,
          description: "Just an awesome project"
        })

      _new_owner_id = Ecto.UUID.generate()

      project_params = %{
        name: "semaphore",
        description: "Even more awesome project"
      }

      repo_params = %{
        url: "git@github.com:semaforko-vcr-tester/hello-world.git"
      }

      schedulers = []
      tasks = []

      {:ok, updated_project} =
        Project.update(
          project,
          project_params,
          repo_params,
          schedulers,
          tasks,
          "requester_id"
        )

      assert updated_project.creator_id == creator_id
    end

    test "when the project name is not valid => returns an error, doesn't update project" do
      {:ok, project} =
        Support.Factories.Project.create(%{
          name: "awesome_project",
          creator_id: Ecto.UUID.generate(),
          organization_id: Ecto.UUID.generate()
        })

      project_params = %{
        name: "awesome project"
      }

      repo_params = %{
        url: "git@github.com:organization/awesome_project.git"
      }

      schedulers = []
      tasks = []

      expected_feedback = {
        :error,
        ["Project name can have only alphanumeric characters, underscore and dash"]
      }

      assert Project.update(project, project_params, repo_params, schedulers, tasks, "requester_id") ==
               expected_feedback

      assert project == Project |> Repo.get(project.id)
    end
  end

  describe ".hard_destroy" do
    test "destroys repo, deploy key, schedulers and project records, removes key and hook from github, destroys artifact" do
      {:ok, project} = Support.Factories.Project.create_with_repo()

      user = %User{github_token: "token"}

      with_mocks([
        {Repository, [:passthrough], [destroy: fn r -> {:ok, r} end]},
        {Events.ProjectDeleted, [], [publish: fn _ -> {:ok, nil} end]},
        {Schedulers, [], [delete_all: fn _p, _r -> {:ok, nil} end]},
        {Projecthub.Artifact, [], [destroy: fn _, _ -> nil end]}
      ]) do
        {:ok, _} = Project.hard_destroy(project, user.id)
        assert_called(Schedulers.delete_all(project, user.id))
        assert_called(Events.ProjectDeleted.publish(project))
        assert_called(Projecthub.Artifact.destroy(project.artifact_store_id, project.id))
        assert_called(Repository.destroy(project.repository))

        projects = Project |> Repo.all()
        assert Enum.empty?(projects)
      end
    end
  end

  describe ".soft_destroy" do
    test "soft deletes the project updating deleted_at and deleted_by" do
      {:ok, project} = Support.Factories.Project.create_with_repo()

      user = %User{github_token: "token"}

      with_mocks([
        {Repository, [:passthrough], [clear_external_data: fn r -> {:ok, r} end]},
        {Events.ProjectDeleted, [], [publish: fn _, _ -> {:ok, nil} end]}
      ]) do
        {:ok, _} = Project.soft_destroy(project, user)

        assert_called(Events.ProjectDeleted.publish(project, soft_delete: true))
        assert_called(Repository.clear_external_data(project.repository))

        # Assert project is not found by default find function
        assert {:error, :not_found} = Project.find(project.id)

        # Assert soft deleted project
        soft_deleted_project = Project |> Repo.get(project.id)
        assert soft_deleted_project.deleted_at != nil
        assert soft_deleted_project.deleted_by == user.id

        cut_timestamp = create_cut_timestamp()
        assert soft_deleted_project.name =~ "#{project.name}-deleted-#{cut_timestamp}"
      end
    end
  end

  describe ".restore" do
    test "restores the project updating deleted_at and deleted_by" do
      %{id: id} = create_and_soft_destroy()

      assert {:error, :not_found} = Project.find(id)
      assert {:ok, project} = Project.find(id, true)

      assert project.deleted_at != nil
      assert project.deleted_by != nil

      {:ok, _} = Project.restore(project)

      assert {:ok, project} = Project.find(project.id)
      assert project.deleted_at == nil
      assert project.deleted_by == nil
    end
  end

  describe ".find" do
    test "when the project exists => returns the project" do
      {:ok, project} = Support.Factories.Project.create()

      {:ok, found_project} = Project.find(project.id)

      assert found_project == project
    end

    test "when the project doesn't exist => returns an error" do
      {:error, :not_found} = Project.find(Ecto.UUID.generate())
    end

    test "when the project is requested by non-uuid => returns an error" do
      {:error, :not_found} = Project.find("semaphore")
    end

    test "when the project is soft deleted => returns an error" do
      project = create_and_soft_destroy()

      assert {:error, :not_found} = Project.find(project.id)
    end

    test "when the project is soft deleted but we query soft_deleted ones => returns the project" do
      project = create_and_soft_destroy()

      {:ok, found_project} = Project.find(project.id, true)
      cut_timestamp = create_cut_timestamp()
      assert found_project.id == project.id
      assert found_project.name == project.name
      assert found_project.name =~ "-deleted-#{cut_timestamp}"
    end
  end

  describe ".find_by_name" do
    test "when the project exists => returns the project" do
      {:ok, project} = Support.Factories.Project.create()

      {:ok, found_project} =
        Project.find_by_name(
          project.name,
          project.organization_id
        )

      assert found_project == project
    end

    test "when the project doesn't exist => returns an error" do
      {:error, :not_found} =
        Project.find_by_name(
          "name",
          Ecto.UUID.generate()
        )
    end

    test "when the project is soft deleted => returns an error" do
      project = create_and_soft_destroy()

      assert {:error, :not_found} = Project.find_by_name(project.name, project.organization_id)
    end

    test "when the project is soft deleted but we query soft_deleted ones => returns the project" do
      project = create_and_soft_destroy()

      {:ok, found_project} = Project.find_by_name(project.name, project.organization_id, true)

      cut_timestamp = create_cut_timestamp()

      assert found_project.id == project.id
      assert found_project.name == project.name
      assert found_project.name =~ "-deleted-#{cut_timestamp}"
    end
  end

  describe ".find_many" do
    test "it returns the projects" do
      org_id = Ecto.UUID.generate()

      {:ok, project1} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      {:ok, project2} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      projects = Project.find_many(org_id, [project1.id, project2.id])

      assert Enum.count(projects) == 2
    end

    test "when the project requested doesn't belong to org => doesn't return it" do
      {:ok, project} = Support.Factories.Project.create()

      projects =
        Project.find_many(
          Ecto.UUID.generate(),
          [project.id]
        )

      assert Enum.empty?(projects)
    end

    test "when the projects are non-existent => returns an empty list" do
      projects =
        Project.find_many(
          Ecto.UUID.generate(),
          [Ecto.UUID.generate()]
        )

      assert Enum.empty?(projects)
    end

    test "when the projects are soft deleted => doesn't return them" do
      [project1, project2] = create_and_soft_destroy_many()

      projects = Project.find_many(Ecto.UUID.generate(), [project1.id, project2.id])

      assert Enum.empty?(projects)
    end

    test "when the projects are soft deleted but we query soft_deleted ones => returns them" do
      org_id = Ecto.UUID.generate()
      [project1, project2] = create_and_soft_destroy_many(org_id: org_id)

      projects = Project.find_many(org_id, [project1.id, project2.id], true)

      cut_timestamp = create_cut_timestamp()
      assert Enum.count(projects) == 2
      assert Enum.all?(projects, fn project -> project.name =~ "-deleted-#{cut_timestamp}" end)
    end
  end

  describe ".list_per_page" do
    test "it returns a page of projects" do
      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      {:ok, _project2} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      {:ok, _project3} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      {:ok, _project4} = Support.Factories.Project.create()

      # Soft deleted project should not be listed
      create_and_soft_destroy()

      page = Project.list_per_page(org_id, 1, 2)

      assert page.page_number == 1
      assert page.page_size == 2
      assert page.total_entries == 3
      assert page.total_pages == 2

      entries = page.entries
      assert Enum.count(entries) == 2
    end

    test "it returns a page of soft deleted projects" do
      org_id = Ecto.UUID.generate()

      cut_timestamp = create_cut_timestamp()
      create_and_soft_destroy_many(org_id: org_id, quantity: 4)

      {:ok, _non_deleted_project} = Support.Factories.Project.create()

      page = Project.list_per_page(org_id, 1, 3, soft_deleted: true)

      assert page.page_number == 1
      assert page.page_size == 3
      assert page.total_entries == 4
      assert page.total_pages == 2

      entries = page.entries
      assert Enum.count(entries) == 3
      assert Enum.all?(entries, fn project -> project.name =~ "-deleted-#{cut_timestamp}" end)
    end

    test "it filter projects by owner_id" do
      org_id = Ecto.UUID.generate()
      owner_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _project2} =
        Support.Factories.Project.create(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _project3} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      {:ok, _project4} = Support.Factories.Project.create()

      page = Project.list_per_page(org_id, 1, 2, owner_id: owner_id)

      assert page.page_number == 1
      assert page.page_size == 2
      assert page.total_entries == 2
      assert page.total_pages == 1

      entries = page.entries
      assert Enum.count(entries) == 2
    end

    test "it filter projects by repo_url" do
      org_id = Ecto.UUID.generate()
      url = "git@github.com/organization:projecthub.git"

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(
          %{
            organization_id: org_id
          },
          %{
            url: url
          }
        )

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(
          %{
            organization_id: org_id
          },
          %{
            url: url
          }
        )

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project4} = Support.Factories.Project.create_with_repo()

      page = Project.list_per_page(org_id, 1, 2, repo_url: url)

      assert page.page_number == 1
      assert page.page_size == 2
      assert page.total_entries == 2
      assert page.total_pages == 1

      entries = page.entries
      assert Enum.count(entries) == 2
    end

    test "it returns only ready projects" do
      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      {:ok, _project2} =
        Support.Factories.Project.create(%{
          organization_id: org_id
        })

      {:ok, _project3} =
        Support.Factories.Project.create(%{
          organization_id: org_id,
          state: "error"
        })

      page = Project.list_per_page(org_id, 1, 3)

      assert page.page_number == 1
      assert page.page_size == 3
      assert page.total_entries == 2
      assert page.total_pages == 1

      entries = page.entries
      assert Enum.count(entries) == 2
    end
  end

  defp create_and_soft_destroy_many(opts \\ []) do
    org_id = opts[:org_id] || Ecto.UUID.generate()
    quantity = opts[:quantity] || 2

    projects =
      for _ <- 1..quantity do
        {:ok, project} = Support.Factories.Project.create_with_repo(%{organization_id: org_id})
        project
      end

    user = %User{id: Ecto.UUID.generate(), github_token: "token"}

    Enum.each(projects, fn project ->
      {:ok, _} = Project.soft_destroy(project, user)
    end)

    projects
  end

  defp create_and_soft_destroy do
    {:ok, project} = Support.Factories.Project.create_with_repo()

    user = %User{id: Ecto.UUID.generate(), github_token: "token"}

    {:ok, _} = Project.soft_destroy(project, user)
    {:ok, project} = Project.find(project.id, true)
    project
  end

  defp create_cut_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:second)
    |> Integer.floor_div(1000)
  end
end
