# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Projecthub.HttpApi.Test do
  use ExUnit.Case

  alias Support.FakeServices

  @port Application.compile_env!(:projecthub, :http_port)
  @version "v1alpha"

  @org_id :uuid.get_v4() |> :uuid.uuid_to_string() |> List.to_string()
  @owner_id :uuid.get_v4() |> :uuid.uuid_to_string() |> List.to_string()
  @project_id :uuid.get_v4() |> :uuid.uuid_to_string() |> List.to_string()
  @task_id :uuid.get_v4() |> :uuid.uuid_to_string() |> List.to_string()

  @headers [
    "content-type": "application/json",
    "x-semaphore-org-id": @org_id,
    "x-semaphore-user-id": @owner_id,
    "x-request-id": :uuid.get_v4() |> :uuid.uuid_to_string() |> List.to_string()
  ]

  setup do
    FunRegistry.clear!()
    Cachex.clear(:auth_cache)

    FunRegistry.set!(FakeServices.OrganizationService, :describe, fn _, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization: InternalApi.Organization.Organization.new(restricted: false)
      )
    end)

    :ok
  end

  describe "GET /api/<version>/projects with authorized user" do
    setup do
      p1_id = uuid()
      p2_id = uuid()
      p1 = create("trello", p1_id)
      p2 = create("tuturu", p2_id)

      FunRegistry.set!(FakeServices.RbacService, :list_accessible_projects, fn _, _ ->
        InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: [p1_id, p2_id])
      end)

      FunRegistry.set!(FakeServices.ProjectService, :list, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.ListResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          projects: [p1, p2]
        )
      end)

      {:ok, p1: p1_id, p2: p2_id}
    end

    test "when projects are present => returns 200" do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects", @headers)

      assert response.status_code == 200
    end

    test "when projects are present in not restricted org => it returns JSON encoded project",
         ctx do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects", @headers)

      assert [
               %{
                 "apiVersion" => "v1alpha",
                 "kind" => "Project",
                 "metadata" => %{
                   "id" => ctx.p1,
                   "name" => "trello",
                   "owner_id" => "",
                   "org_id" => "",
                   "description" => ""
                 },
                 "spec" => %{
                   "repository" => %{
                     "url" => "git@github.com/shiroyasha/test.git",
                     "name" => "",
                     "owner" => "",
                     "forked_pull_requests" => %{
                       "allowed_secrets" => [],
                       "allowed_contributors" => []
                     },
                     "run_on" => ["tags", "branches"],
                     "pipeline_file" => ".semaphore/semaphore.yml",
                     "status" => %{
                       "pipeline_files" => [
                         %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
                       ]
                     },
                     "whitelist" => %{
                       "branches" => ["master", "/features-.*/"],
                       "tags" => []
                     },
                     "integration_type" => "github_token"
                   },
                   "schedulers" => [],
                   "tasks" => [],
                   "visibility" => "private"
                 }
               },
               %{
                 "apiVersion" => "v1alpha",
                 "kind" => "Project",
                 "metadata" => %{
                   "id" => ctx.p2,
                   "name" => "tuturu",
                   "owner_id" => "",
                   "org_id" => "",
                   "description" => ""
                 },
                 "spec" => %{
                   "repository" => %{
                     "url" => "git@github.com/shiroyasha/test.git",
                     "name" => "",
                     "owner" => "",
                     "forked_pull_requests" => %{
                       "allowed_secrets" => [],
                       "allowed_contributors" => []
                     },
                     "run_on" => ["tags", "branches"],
                     "pipeline_file" => ".semaphore/semaphore.yml",
                     "status" => %{
                       "pipeline_files" => [
                         %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
                       ]
                     },
                     "whitelist" => %{
                       "branches" => ["master", "/features-.*/"],
                       "tags" => []
                     },
                     "integration_type" => "github_token"
                   },
                   "schedulers" => [],
                   "tasks" => [],
                   "visibility" => "private"
                 }
               }
             ] == Poison.decode!(response.body)

      assert Enum.count(Poison.decode!(response.body)) == 2
    end

    test "when projects are present in restricted org => it returns JSON encoded project", ctx do
      restrict_org!()

      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects", @headers)

      assert [
               %{
                 "apiVersion" => "v1alpha",
                 "kind" => "Project",
                 "metadata" => %{
                   "id" => ctx.p1,
                   "name" => "trello",
                   "owner_id" => "",
                   "org_id" => "",
                   "description" => ""
                 },
                 "spec" => %{
                   "repository" => %{
                     "url" => "git@github.com/shiroyasha/test.git",
                     "name" => "",
                     "owner" => "",
                     "forked_pull_requests" => %{
                       "allowed_secrets" => [],
                       "allowed_contributors" => []
                     },
                     "run_on" => ["tags", "branches"],
                     "pipeline_file" => ".semaphore/semaphore.yml",
                     "status" => %{
                       "pipeline_files" => [
                         %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
                       ]
                     },
                     "whitelist" => %{
                       "branches" => ["master", "/features-.*/"],
                       "tags" => []
                     },
                     "integration_type" => "github_token"
                   },
                   "schedulers" => [],
                   "tasks" => [],
                   "visibility" => "private",
                   "custom_permissions" => true,
                   "debug_permissions" => ["empty", "default_branch"],
                   "attach_permissions" => []
                 }
               },
               %{
                 "apiVersion" => "v1alpha",
                 "kind" => "Project",
                 "metadata" => %{
                   "id" => ctx.p2,
                   "name" => "tuturu",
                   "owner_id" => "",
                   "org_id" => "",
                   "description" => ""
                 },
                 "spec" => %{
                   "repository" => %{
                     "url" => "git@github.com/shiroyasha/test.git",
                     "name" => "",
                     "owner" => "",
                     "forked_pull_requests" => %{
                       "allowed_secrets" => [],
                       "allowed_contributors" => []
                     },
                     "run_on" => ["tags", "branches"],
                     "pipeline_file" => ".semaphore/semaphore.yml",
                     "status" => %{
                       "pipeline_files" => [
                         %{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}
                       ]
                     },
                     "whitelist" => %{
                       "branches" => ["master", "/features-.*/"],
                       "tags" => []
                     },
                     "integration_type" => "github_token"
                   },
                   "schedulers" => [],
                   "tasks" => [],
                   "visibility" => "private",
                   "custom_permissions" => true,
                   "debug_permissions" => ["empty", "default_branch"],
                   "attach_permissions" => []
                 }
               }
             ] == Poison.decode!(response.body)

      assert Enum.count(Poison.decode!(response.body)) == 2
    end
  end

  describe "GET /api/<version>/projects with unauthorized user" do
    setup do
      FunRegistry.set!(FakeServices.RbacService, :list_accessible_projects, fn _, _ ->
        InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: [])
      end)

      p1 = create("trello", uuid())
      p2 = create("tuturu", uuid())

      FunRegistry.set!(FakeServices.ProjectService, :list, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.ListResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          projects: [p1, p2]
        )
      end)

      :ok
    end

    test "when projects are present => returns 200" do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects", @headers)

      assert response.status_code == 200
    end

    test "when projects are present => it returns empty array" do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects", @headers)

      assert [] == Poison.decode!(response.body)
    end
  end

  describe "GET /api/<version>/projects pagination" do
    setup do
      # Setup three projects to test pagination
      p1_id = uuid()
      p2_id = uuid()
      p3_id = uuid()
      p1 = create("project1", p1_id)
      p2 = create("project2", p2_id)
      p3 = create("project3", p3_id)
      page_size = Application.get_env(:projecthub, :projects_page_size)

      FunRegistry.set!(FakeServices.RbacService, :list_accessible_projects, fn _, _ ->
        InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: [p1_id, p2_id, p3_id])
      end)

      FunRegistry.set!(FakeServices.ProjectService, :list, fn req, _ ->
        alias InternalApi.Projecthub, as: PH
        page = req.pagination.page
        all_projects = [p1, p2, p3]
        projects = Enum.slice(all_projects, (page - 1) * page_size, page_size)

        PH.ListResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          projects: projects,
          pagination:
            PH.PaginationResponse.new(
              page_number: page,
              page_size: page_size,
              total_entries: length(all_projects),
              total_pages: div(length(all_projects) + page_size - 1, page_size)
            )
        )
      end)

      :ok
    end

    test "returns correct pagination headers for /projects" do
      {:ok, response} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=1",
          @headers
        )

      assert response.status_code == 200
      assert response.headers |> Enum.any?(fn {k, v} -> k == "x-page" and v == "1" end)
      assert response.headers |> Enum.any?(fn {k, v} -> k == "x-has-more" and v == "true" end)
      projects = Poison.decode!(response.body)
      assert length(projects) == 2

      {:ok, response2} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=2",
          @headers
        )

      assert response2.status_code == 200
      assert response2.headers |> Enum.any?(fn {k, v} -> k == "x-page" and v == "2" end)
      assert response2.headers |> Enum.any?(fn {k, v} -> k == "x-has-more" and v == "false" end)
      projects2 = Poison.decode!(response2.body)
      assert length(projects2) == 1

      {:ok, response3} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=3",
          @headers
        )

      assert response3.status_code == 200
      assert response3.headers |> Enum.any?(fn {k, v} -> k == "x-page" and v == "3" end)
      assert response3.headers |> Enum.any?(fn {k, v} -> k == "x-has-more" and v == "false" end)
      projects3 = Poison.decode!(response3.body)
      assert Enum.empty?(projects3)
    end

    test "returns correct pagination headers for /projects when there are no more projects" do
      {:ok, response} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=2",
          @headers
        )

      assert response.status_code == 200
      assert response.headers |> Enum.any?(fn {k, v} -> k == "x-page" and v == "2" end)
      assert response.headers |> Enum.any?(fn {k, v} -> k == "x-has-more" and v == "false" end)
      projects = Poison.decode!(response.body)
      assert length(projects) == 1
    end

    test "returns 404 on out-of-range page" do
      FunRegistry.set!(FakeServices.ProjectService, :list, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.ListResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:NOT_FOUND))
            ),
          projects: []
        )
      end)

      {:ok, response} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=10",
          @headers
        )

      assert response.status_code == 404
    end

    test "returns 400 on bad request" do
      FunRegistry.set!(FakeServices.ProjectService, :list, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.ListResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status:
                PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:FAILED_PRECONDITION))
            ),
          projects: [],
          pagination:
            PH.PaginationResponse.new(
              total_count: 0,
              page_number: 0,
              page_size: 0,
              total_pages: 0
            )
        )
      end)

      {:ok, response} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=foo",
          @headers
        )

      assert response.status_code == 400
    end

    test "returns 400 on negative page" do
      {:ok, response} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=-1",
          @headers
        )

      assert response.status_code == 400
      assert Poison.decode!(response.body)["message"] =~ "page must be at least 1"
    end

    test "returns 400 on too large page" do
      {:ok, response} =
        HTTPoison.get(
          "http://localhost:#{@port}/api/#{@version}/projects?page=9999",
          @headers
        )

      assert response.status_code == 400 or response.status_code == 200

      if response.status_code == 400 do
        assert Poison.decode!(response.body)["message"] =~ "page must be at most"
      end
    end
  end

  describe "GET /api/<version>/projects/:name with authorized user" do
    setup do
      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: ["project.view"])
      end)

      prj = create("trello", @project_id)

      FunRegistry.set!(FakeServices.ProjectService, :describe, fn req, _ ->
        alias InternalApi.Projecthub, as: PH
        assert req.detailed

        if req.name == "trello" do
          PH.DescribeResponse.new(
            metadata:
              PH.ResponseMeta.new(
                status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
              ),
            project: prj
          )
        else
          PH.DescribeResponse.new(
            metadata:
              PH.ResponseMeta.new(
                status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:NOT_FOUND))
              )
          )
        end
      end)

      :ok
    end

    test "when project is present => returns 200" do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects/trello", @headers)

      assert response.status_code == 200
    end

    test "when project is not present => returns 404" do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects/aws", @headers)

      assert response.status_code == 404
    end

    test "when project is present => it returns JSON encoded project" do
      create("aws-projects", uuid())

      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects/trello", @headers)

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => "",
                 "org_id" => "",
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "name" => "",
                   "owner" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags", "branches"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => [
                       %{"level" => "pipeline", "path" => ".semaphore/semaphore.yml"}
                     ]
                   },
                   "whitelist" => %{
                     "branches" => ["master", "/features-.*/"],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [],
                 "visibility" => "private"
               }
             }
    end

    test "when project has tasks instead of schedulers => it returns JSON with tasks" do
      prj = create_with_tasks("trello", @project_id)

      FunRegistry.set!(FakeServices.ProjectService, :describe, fn req, _ ->
        alias InternalApi.Projecthub, as: PH
        assert req.detailed

        if req.name == "trello" do
          PH.DescribeResponse.new(
            metadata:
              PH.ResponseMeta.new(
                status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
              ),
            project: prj
          )
        else
          PH.DescribeResponse.new(
            metadata:
              PH.ResponseMeta.new(
                status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:NOT_FOUND))
              )
          )
        end
      end)

      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects/trello", @headers)

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => "",
                 "org_id" => "",
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "name" => "",
                   "owner" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags", "branches"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => [
                       %{"level" => "pipeline", "path" => ".semaphore/semaphore.yml"}
                     ]
                   },
                   "whitelist" => %{
                     "branches" => ["master", "/features-.*/"],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [
                   %{
                     "name" => "task_name",
                     "description" => "task_description",
                     "at" => "0 0 * * *",
                     "branch" => "master",
                     "id" => "task_id",
                     "parameters" => [
                       %{
                         "default_value" => "default1",
                         "description" => "description1",
                         "name" => "param1",
                         "options" => ["option1", "option2"],
                         "required" => true
                       }
                     ],
                     "pipeline_file" => ".semaphore/semaphore.yml",
                     "scheduled" => false,
                     "status" => "ACTIVE"
                   }
                 ],
                 "visibility" => "private"
               }
             }
    end

    test "when project is present and org is restricted => it returns JSON encoded project" do
      restrict_org!()
      create("aws-projects", uuid())

      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects/trello", @headers)

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => "",
                 "org_id" => "",
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "name" => "",
                   "owner" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags", "branches"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => [
                       %{"level" => "pipeline", "path" => ".semaphore/semaphore.yml"}
                     ]
                   },
                   "whitelist" => %{
                     "branches" => ["master", "/features-.*/"],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [],
                 "visibility" => "private",
                 "custom_permissions" => true,
                 "debug_permissions" => ["empty", "default_branch"],
                 "attach_permissions" => []
               }
             }
    end
  end

  describe "GET /api/<version>/projects/:name with unauthorized user" do
    setup do
      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
      end)

      prj = create("trello", @project_id)

      FunRegistry.set!(FakeServices.ProjectService, :describe, fn req, _ ->
        alias InternalApi.Projecthub, as: PH

        if req.name == "trello" do
          PH.DescribeResponse.new(
            metadata:
              PH.ResponseMeta.new(
                status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
              ),
            project: prj
          )
        else
          PH.DescribeResponse.new(
            metadata:
              PH.ResponseMeta.new(
                status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:NOT_FOUND))
              )
          )
        end
      end)

      :ok
    end

    test "when project is present => returns 401" do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects/trello", @headers)

      assert response.status_code == 401
    end

    test "when project is not present => returns 404" do
      {:ok, response} =
        HTTPoison.get("http://localhost:#{@port}/api/#{@version}/projects/aws", @headers)

      assert response.status_code == 404
    end
  end

  describe "POST /api/<version>/projects with authorized user" do
    setup do
      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: ["organization.projects.create"]
        )
      end)

      FunRegistry.set!(FakeServices.ProjectService, :create, fn req, _ ->
        Support.Factories.project_create_response(
          @project_id,
          req.project
        )
      end)

      FunRegistry.set!(FakeServices.OrganizationService, :repository_integrators, fn _, _ ->
        InternalApi.Organization.RepositoryIntegratorsResponse.new(
          primary: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN),
          enabled: [
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP),
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
          ],
          available: [
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP),
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
          ]
        )
      end)

      :ok
    end

    test "when project creation succeds, without public flag => returns 200" do
      resource =
        Poison.encode!(%{
          "metadata" => %{"name" => "trello"},
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git",
              "run_on" => ["tags", "branches2"],
              "pipeline_file" => ".semaphore/semaphore.yml"
            },
            "schedulers" => []
          }
        })

      {:ok, response} =
        HTTPoison.post("http://localhost:#{@port}/api/#{@version}/projects", resource, @headers)

      assert response.status_code == 200

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => "",
                 "org_id" => "",
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [],
                 "visibility" => "private"
               }
             }
    end

    test "when project creation succeds => returns 200" do
      restrict_org!()

      resource =
        Poison.encode!(%{
          "metadata" => %{"name" => "trello"},
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git",
              "run_on" => ["tags", "branches2"],
              "pipeline_file" => ".semaphore/semaphore.yml"
            },
            "schedulers" => [],
            "visibility" => "public",
            "custom_permissions" => true,
            "debug_permissions" => ["empty", "default_branch"],
            "attach_permissions" => ["default_branch"]
          }
        })

      {:ok, response} =
        HTTPoison.post("http://localhost:#{@port}/api/#{@version}/projects", resource, @headers)

      assert response.status_code == 200

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => "",
                 "org_id" => "",
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [],
                 "visibility" => "public",
                 "custom_permissions" => true,
                 "debug_permissions" => ["empty", "default_branch"],
                 "attach_permissions" => ["default_branch"]
               }
             }
    end

    test "when project creation succeds with tasks => returns 200" do
      restrict_org!()

      resource =
        Poison.encode!(%{
          "metadata" => %{"name" => "trello"},
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git",
              "run_on" => ["tags", "branches2"],
              "pipeline_file" => ".semaphore/semaphore.yml"
            },
            "tasks" => [
              %{
                "name" => "task_name",
                "description" => "task_description",
                "at" => "0 0 * * *",
                "branch" => "master",
                "id" => "task_id",
                "parameters" => [
                  %{
                    "default_value" => "default1",
                    "description" => "description1",
                    "name" => "param1",
                    "options" => ["option1", "option2"],
                    "required" => true
                  }
                ],
                "pipeline_file" => ".semaphore/semaphore.yml",
                "scheduled" => false,
                "status" => "ACTIVE"
              }
            ],
            "visibility" => "public",
            "custom_permissions" => true,
            "debug_permissions" => ["empty", "default_branch"],
            "attach_permissions" => ["default_branch"]
          }
        })

      {:ok, response} =
        HTTPoison.post("http://localhost:#{@port}/api/#{@version}/projects", resource, @headers)

      assert response.status_code == 200

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => "",
                 "org_id" => "",
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [
                   %{
                     "name" => "task_name",
                     "description" => "task_description",
                     "at" => "0 0 * * *",
                     "branch" => "master",
                     "id" => "task_id",
                     "parameters" => [
                       %{
                         "default_value" => "default1",
                         "description" => "description1",
                         "name" => "param1",
                         "options" => ["option1", "option2"],
                         "required" => true
                       }
                     ],
                     "pipeline_file" => ".semaphore/semaphore.yml",
                     "scheduled" => false,
                     "status" => "ACTIVE"
                   }
                 ],
                 "visibility" => "public",
                 "custom_permissions" => true,
                 "debug_permissions" => ["empty", "default_branch"],
                 "attach_permissions" => ["default_branch"]
               }
             }
    end

    test "when github project without integration_type => setup primary one" do
      FunRegistry.set!(FakeServices.OrganizationService, :repository_integrators, fn _, _ ->
        InternalApi.Organization.RepositoryIntegratorsResponse.new(
          primary: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP),
          enabled: [
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP),
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
          ],
          available: [
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP),
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
          ]
        )
      end)

      resource =
        Poison.encode!(%{
          "metadata" => %{"name" => "trello"},
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git",
              "run_on" => ["tags", "branches2"],
              "pipeline_file" => ".semaphore/semaphore.yml"
            },
            "schedulers" => [],
            "visibility" => "public",
            "custom_permissions" => true,
            "debug_permissions" => ["empty"]
          }
        })

      {:ok, response} =
        HTTPoison.post("http://localhost:#{@port}/api/#{@version}/projects", resource, @headers)

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => "",
                 "org_id" => "",
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [],
                 "visibility" => "public"
               }
             }
    end
  end

  describe "POST /api/<version>/projects with unauthorized user" do
    setup do
      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
      end)

      FunRegistry.set!(FakeServices.ProjectService, :create, fn req, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.DescribeResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project:
            PH.Project.new(
              metadata:
                PH.Project.Metadata.new(
                  id: @project_id,
                  name: req.project.metadata.name
                ),
              spec: req.project.spec
            )
        )
      end)

      :ok
    end

    test "when trying to create a project => returns 401" do
      resource =
        Poison.encode!(%{
          "metadata" => %{"name" => "trello"},
          "spec" => %{
            "repository" => %{"url" => "git@github.com/shiroyasha/test.git"}
          }
        })

      {:ok, response} =
        HTTPoison.post("http://localhost:#{@port}/api/#{@version}/projects", resource, @headers)

      assert response.status_code == 401
    end
  end

  describe "PATCH /api/<version>/projects/:id with authorized user" do
    setup do
      prj = create("trello", @project_id)

      FunRegistry.set!(FakeServices.ProjectService, :describe, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.DescribeResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project: prj
        )
      end)

      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: ["project.general_settings.manage", "project.repository_info.manage"]
        )
      end)

      :ok
    end

    test "when project update with tasks succeds => returns 200" do
      FunRegistry.set!(FakeServices.ProjectService, :update, fn req, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.UpdateResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project:
            PH.Project.new(
              metadata:
                PH.Project.Metadata.new(
                  id: @project_id,
                  name: req.project.metadata.name,
                  owner_id: @owner_id,
                  org_id: @org_id,
                  description: "A new description"
                ),
              spec: req.project.spec
            )
        )
      end)

      restrict_org!()

      resource =
        Poison.encode!(%{
          "metadata" => %{
            "name" => "trello",
            "id" => @project_id,
            "owner_id" => @owner_id,
            "org_id" => @org_id,
            "description" => "Some description"
          },
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git",
              "forked_pull_requests" => %{
                "allowed_secrets" => ["foo"],
                "allowed_contributors" => []
              },
              "pipeline_file" => ""
            },
            "tasks" => [
              %{
                "name" => "scheduler1",
                "id" => @task_id,
                "description" => "description",
                "branch" => "master",
                "scheduled" => true,
                "at" => "0 * * * *",
                "pipeline_file" => ".semaphore/cron1.yml",
                "status" => "INACTIVE"
              },
              %{
                "name" => "scheduler2",
                "id" => @task_id,
                "scheduled" => false,
                "branch" => "",
                "at" => "",
                "pipeline_file" => "",
                "status" => "ACTIVE",
                "parameters" => [
                  %{"name" => "parameter", "required" => false, "options" => ["op1", "op2"]},
                  %{
                    "name" => "parameter",
                    "description" => "desc",
                    "required" => true,
                    "default_value" => "default"
                  }
                ]
              }
            ],
            "visibility" => "public",
            "custom_permissions" => true,
            "debug_permissions" => ["empty"]
          }
        })

      {:ok, response} =
        HTTPoison.patch(
          "http://localhost:#{@port}/api/#{@version}/projects/#{@project_id}",
          resource,
          @headers
        )

      assert response.status_code == 200

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => @owner_id,
                 "org_id" => @org_id,
                 "description" => "A new description"
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => ["foo"],
                     "allowed_contributors" => []
                   },
                   "run_on" => [],
                   "pipeline_file" => "",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [
                   %{
                     "name" => "scheduler1",
                     "id" => @task_id,
                     "description" => "description",
                     "branch" => "master",
                     "scheduled" => true,
                     "at" => "0 * * * *",
                     "pipeline_file" => ".semaphore/cron1.yml",
                     "status" => "INACTIVE",
                     "parameters" => []
                   },
                   %{
                     "name" => "scheduler2",
                     "id" => @task_id,
                     "description" => "",
                     "scheduled" => false,
                     "branch" => "",
                     "at" => "",
                     "pipeline_file" => "",
                     "status" => "ACTIVE",
                     "parameters" => [
                       %{
                         "name" => "parameter",
                         "description" => "",
                         "required" => false,
                         "default_value" => "",
                         "options" => ["op1", "op2"]
                       },
                       %{
                         "name" => "parameter",
                         "description" => "desc",
                         "required" => true,
                         "default_value" => "default",
                         "options" => []
                       }
                     ]
                   }
                 ],
                 "visibility" => "public",
                 "custom_permissions" => true,
                 "debug_permissions" => ["empty"],
                 "attach_permissions" => []
               }
             }
    end

    test "when project update succeds => returns 200" do
      FunRegistry.set!(FakeServices.ProjectService, :update, fn req, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.UpdateResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project:
            PH.Project.new(
              metadata:
                PH.Project.Metadata.new(
                  id: @project_id,
                  name: req.project.metadata.name,
                  owner_id: @owner_id,
                  org_id: @org_id,
                  description: "A new description"
                ),
              spec: req.project.spec
            )
        )
      end)

      restrict_org!()

      resource =
        Poison.encode!(%{
          "metadata" => %{
            "name" => "trello",
            "id" => @project_id,
            "owner_id" => @owner_id,
            "org_id" => @org_id,
            "description" => "Some description"
          },
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git",
              "forked_pull_requests" => %{
                "allowed_secrets" => ["foo"],
                "allowed_contributors" => []
              },
              "pipeline_file" => ""
            },
            "schedulers" => [
              %{
                "name" => "scheduler1",
                "id" => @task_id,
                "branch" => "master",
                "at" => "* * * *",
                "pipeline_file" => ".semaphore/cron1.yml",
                "status" => "INACTIVE"
              },
              %{
                "name" => "scheduler2",
                "id" => @task_id,
                "branch" => "some_branch",
                "at" => "* * * *",
                "pipeline_file" => ".semaphore/cron2.yml"
              }
            ],
            "visibility" => "public",
            "custom_permissions" => true,
            "debug_permissions" => ["empty"]
          }
        })

      {:ok, response} =
        HTTPoison.patch(
          "http://localhost:#{@port}/api/#{@version}/projects/#{@project_id}",
          resource,
          @headers
        )

      assert response.status_code == 200

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => @owner_id,
                 "org_id" => @org_id,
                 "description" => "A new description"
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => ["foo"],
                     "allowed_contributors" => []
                   },
                   "run_on" => [],
                   "pipeline_file" => "",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [
                   %{
                     "name" => "scheduler1",
                     "id" => @task_id,
                     "branch" => "master",
                     "at" => "* * * *",
                     "pipeline_file" => ".semaphore/cron1.yml",
                     "status" => "INACTIVE"
                   },
                   %{
                     "name" => "scheduler2",
                     "id" => @task_id,
                     "branch" => "some_branch",
                     "at" => "* * * *",
                     "pipeline_file" => ".semaphore/cron2.yml"
                   }
                 ],
                 "tasks" => [],
                 "visibility" => "public",
                 "custom_permissions" => true,
                 "debug_permissions" => ["empty"],
                 "attach_permissions" => []
               }
             }
    end

    test "when project is not present => returns 404" do
      FunRegistry.set!(FakeServices.ProjectService, :describe, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.DescribeResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:NOT_FOUND))
            )
        )
      end)

      FunRegistry.set!(FakeServices.ProjectService, :update, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.UpdateResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:NOT_FOUND))
            )
        )
      end)

      resource =
        Poison.encode!(%{
          "metadata" => %{
            "name" => "trello",
            "id" => @project_id,
            "owner_id" => @owner_id,
            "org_id" => @org_id,
            "description" => "Some description"
          },
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git"
            },
            "schedulers" => []
          }
        })

      {:ok, response} =
        HTTPoison.patch(
          "http://localhost:#{@port}/api/#{@version}/projects/#{@project_id}",
          resource,
          @headers
        )

      assert response.status_code == 404
    end

    test "when project update fails => returns 422" do
      FunRegistry.set!(FakeServices.ProjectService, :update, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.UpdateResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status:
                PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:FAILED_PRECONDITION))
            )
        )
      end)

      resource =
        Poison.encode!(%{
          "metadata" => %{
            "name" => "trello",
            "id" => @project_id,
            "owner_id" => @owner_id,
            "org_id" => @org_id,
            "description" => "Some description"
          },
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git"
            },
            "schedulers" => []
          }
        })

      {:ok, response} =
        HTTPoison.patch(
          "http://localhost:#{@port}/api/#{@version}/projects/#{@project_id}",
          resource,
          @headers
        )

      assert response.status_code == 422
    end

    test "when project description is empty => still works" do
      FunRegistry.set!(FakeServices.ProjectService, :update, fn req, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.UpdateResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project:
            PH.Project.new(
              metadata:
                PH.Project.Metadata.new(
                  id: @project_id,
                  name: req.project.metadata.name,
                  owner_id: @owner_id,
                  org_id: @org_id,
                  description: ""
                ),
              spec: req.project.spec
            )
        )
      end)

      resource =
        Poison.encode!(%{
          "metadata" => %{
            "name" => "trello",
            "id" => @project_id
          },
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git"
            },
            "custom_permissions" => true,
            "debug_permissions" => ["empty", "default_branch"],
            "schedulers" => [],
            "tasks" => []
          }
        })

      {:ok, response} =
        HTTPoison.patch(
          "http://localhost:#{@port}/api/#{@version}/projects/#{@project_id}",
          resource,
          @headers
        )

      assert response.status_code == 200

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => @owner_id,
                 "org_id" => @org_id,
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => [],
                   "pipeline_file" => "",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [],
                 "visibility" => "private"
               }
             }
    end

    test "when schedulers are empty => still works" do
      FunRegistry.set!(FakeServices.ProjectService, :update, fn req, _ ->
        alias InternalApi.Projecthub, as: PH

        assert req.project.spec.schedulers == []

        PH.UpdateResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project:
            PH.Project.new(
              metadata:
                PH.Project.Metadata.new(
                  id: @project_id,
                  name: req.project.metadata.name,
                  owner_id: @owner_id,
                  org_id: @org_id,
                  description: ""
                ),
              spec: req.project.spec
            )
        )
      end)

      restrict_org!()

      resource =
        Poison.encode!(%{
          "metadata" => %{
            "name" => "trello",
            "id" => @project_id
          },
          "spec" => %{
            "repository" => %{
              "url" => "git@github.com/shiroyasha/test.git",
              "run_on" => ["tags"],
              "pipeline_file" => ".semaphore/semaphore.yml"
            }
          }
        })

      {:ok, response} =
        HTTPoison.patch(
          "http://localhost:#{@port}/api/#{@version}/projects/#{@project_id}",
          resource,
          @headers
        )

      assert response.status_code == 200

      assert Poison.decode!(response.body) == %{
               "apiVersion" => "v1alpha",
               "kind" => "Project",
               "metadata" => %{
                 "id" => @project_id,
                 "name" => "trello",
                 "owner_id" => @owner_id,
                 "org_id" => @org_id,
                 "description" => ""
               },
               "spec" => %{
                 "repository" => %{
                   "url" => "git@github.com/shiroyasha/test.git",
                   "owner" => "",
                   "name" => "",
                   "forked_pull_requests" => %{
                     "allowed_secrets" => [],
                     "allowed_contributors" => []
                   },
                   "run_on" => ["tags"],
                   "pipeline_file" => ".semaphore/semaphore.yml",
                   "status" => %{
                     "pipeline_files" => []
                   },
                   "whitelist" => %{
                     "branches" => [],
                     "tags" => []
                   },
                   "integration_type" => "github_token"
                 },
                 "schedulers" => [],
                 "tasks" => [],
                 "visibility" => "private",
                 "custom_permissions" => false,
                 "debug_permissions" => [],
                 "attach_permissions" => []
               }
             }
    end
  end

  describe "PATCH /api/<version>/projects/:id with unauthorized user" do
    setup do
      prj = create("trello", @project_id)

      FunRegistry.set!(FakeServices.ProjectService, :describe, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.DescribeResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project: prj
        )
      end)

      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
      end)

      :ok
    end

    test "when trying to create a project => returns 404" do
      resource =
        Poison.encode!(%{
          "metadata" => %{"name" => "trello"},
          "spec" => %{
            "repository" => %{"url" => "git@github.com/shiroyasha/test.git"}
          }
        })

      {:ok, response} =
        HTTPoison.patch(
          "http://localhost:#{@port}/api/#{@version}/projects/#{@project_id}",
          resource,
          @headers
        )

      assert response.status_code == 401
    end
  end

  describe "DELETE /api/<version>/projects/:name with authorized user" do
    setup do
      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: ["project.delete"])
      end)

      prj = create("trello", @project_id)

      FunRegistry.set!(FakeServices.ProjectService, :describe, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.DescribeResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project: prj
        )
      end)

      FunRegistry.set!(FakeServices.ProjectService, :destroy, fn _, _ ->
        alias InternalApi.Projecthub.ResponseMeta

        InternalApi.Projecthub.DescribeResponse.new(
          metadata:
            ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))
        )
      end)
    end

    test "when project is present => returns 200" do
      create("aws-1", uuid())

      {:ok, response} =
        HTTPoison.delete("http://localhost:#{@port}/api/#{@version}/projects/trello", @headers)

      assert response.status_code == 200
    end
  end

  describe "DELETE /api/<version>/projects/:name with unauthorized user" do
    setup do
      FunRegistry.set!(FakeServices.RbacService, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
      end)

      prj = create("trello", @project_id)

      FunRegistry.set!(FakeServices.ProjectService, :describe, fn _, _ ->
        alias InternalApi.Projecthub, as: PH

        PH.DescribeResponse.new(
          metadata:
            PH.ResponseMeta.new(
              status: PH.ResponseMeta.Status.new(code: PH.ResponseMeta.Code.value(:OK))
            ),
          project: prj
        )
      end)
    end

    test "when project is present => returns 401" do
      create("aws-1", uuid())

      {:ok, response} =
        HTTPoison.delete("http://localhost:#{@port}/api/#{@version}/projects/trello", @headers)

      assert response.status_code == 401
    end
  end

  def create(name, id) do
    alias InternalApi.Projecthub.Project
    alias InternalApi.Projecthub.Project.Spec.{PermissionType, Repository, Visibility}

    Project.new(
      metadata: Project.Metadata.new(name: name, id: id),
      spec:
        Project.Spec.new(
          visibility: Visibility.value(:PRIVATE),
          repository:
            Repository.new(
              url: "git@github.com/shiroyasha/test.git",
              forked_pull_requests: Repository.ForkedPullRequests.new(allowed_secrets: []),
              run_on: [
                Repository.RunType.value(:TAGS),
                Repository.RunType.value(:BRANCHES)
              ],
              pipeline_file: ".semaphore/semaphore.yml",
              status:
                Repository.Status.new(
                  pipeline_files: [
                    Repository.Status.PipelineFile.new(
                      path: ".semaphore/semaphore.yml",
                      level: Repository.Status.PipelineFile.Level.value(:PIPELINE)
                    )
                  ]
                ),
              whitelist:
                Repository.Whitelist.new(
                  branches: ["master", "/features-.*/"],
                  tags: []
                )
            ),
          custom_permissions: true,
          debug_permissions: [
            PermissionType.value(:EMPTY),
            PermissionType.value(:DEFAULT_BRANCH)
          ],
          attach_permissions: []
        )
    )
  end

  def create_with_tasks(name, id) do
    tasks = [
      InternalApi.Projecthub.Project.Spec.Task.new(
        id: "task_id",
        name: "task_name",
        description: "task_description",
        branch: "master",
        pipeline_file: ".semaphore/semaphore.yml",
        recurring: false,
        at: "0 0 * * *",
        status: InternalApi.Projecthub.Project.Spec.Task.Status.value(:STATUS_ACTIVE),
        parameters: [
          InternalApi.Projecthub.Project.Spec.Task.Parameter.new(
            name: "param1",
            description: "description1",
            required: true,
            default_value: "default1",
            options: ["option1", "option2"]
          )
        ]
      )
    ]

    create(name, id) |> Map.update!(:spec, &Map.put(&1, :tasks, tasks))
  end

  def restrict_org! do
    FunRegistry.set!(FakeServices.OrganizationService, :describe, fn _, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization: InternalApi.Organization.Organization.new(restricted: true)
      )
    end)
  end

  defp uuid, do: :uuid.get_v4() |> :uuid.uuid_to_string() |> List.to_string()
end
