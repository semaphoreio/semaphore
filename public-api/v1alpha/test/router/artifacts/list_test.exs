defmodule PipelinesAPI.Artifacts.ListTest do
  use ExUnit.Case

  alias Support.Stubs.{Job, Pipeline, Workflow}

  @job_artifact_url "https://localhost:9000/agent/job_logs.txt.gz"
  @workflow_artifact_url "https://localhost:9000/debug/workflow_logs.txt"
  @project_artifact_url "https://localhost:9000/releases/build.tar.gz"

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    Support.Stubs.Feature.set_org_defaults(org.id)
    Support.Stubs.Feature.enable_feature(org.id, :artifacts_api)
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    build_req_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}

    workflow = Workflow.create(hook, user.id, organization_id: org.id)
    pipeline = Pipeline.create_initial(workflow)

    _block =
      Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"],
        build_req_id: build_req_id
      })

    job = Job.create(pipeline.id, build_req_id, project_id: project.id)

    Support.Stubs.Artifacthub.create(job.api_model.id,
      scope: "jobs",
      path: "agent/job_logs.txt.gz",
      url: @job_artifact_url
    )

    Support.Stubs.Artifacthub.create(workflow.api_model.wf_id,
      scope: "workflows",
      path: "debug/workflow_logs.txt",
      url: @workflow_artifact_url
    )

    Support.Stubs.Artifacthub.create(project.id,
      scope: "projects",
      path: "releases/build.tar.gz",
      url: @project_artifact_url
    )

    {:ok,
     %{org: org, user: user, project: project, workflow: workflow.api_model, job: job.api_model}}
  end

  describe "GET /artifacts" do
    test "returns 200 and job artifacts root listing", ctx do
      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "agent",
                 "path" => "agent"
               }
             ]
    end

    test "returns 200 and workflow artifacts root listing", ctx do
      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "workflows",
                   "scope_id" => ctx.workflow.wf_id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "debug",
                 "path" => "debug"
               }
             ]
    end

    test "returns 200 and project artifacts root listing", ctx do
      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "projects",
                   "scope_id" => ctx.project.id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "releases",
                 "path" => "releases"
               }
             ]
    end

    test "returns 200 and nested listing for a specific path", ctx do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _ ->
        InternalApi.Artifacthub.ListPathResponse.new(
          items: [
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/jobs/#{ctx.job.id}/agent/job_logs.txt.gz",
              is_directory: false,
              size: 2048
            )
          ]
        )
      end)

      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent"
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => false,
                 "name" => "job_logs.txt.gz",
                 "path" => "agent/job_logs.txt.gz",
                 "size" => 2048
               }
             ]
    end

    test "returns all artifacts in the selected path", ctx do
      Support.Stubs.Artifacthub.create(ctx.job.id,
        scope: "jobs",
        path: "agent/extra.log",
        url: "https://localhost:9000/agent/extra.log"
      )

      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent"
                 },
                 ctx.user.id
               )

      assert length(response["artifacts"]) == 2
    end

    test "preserves backend artifact order", ctx do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _ ->
        InternalApi.Artifacthub.ListPathResponse.new(
          items: [
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/jobs/#{ctx.job.id}/agent/z.log",
              is_directory: false,
              size: 128
            ),
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/jobs/#{ctx.job.id}/agent/a.log",
              is_directory: false,
              size: 256
            ),
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/jobs/#{ctx.job.id}/agent/job_logs.txt.gz",
              is_directory: false,
              size: 1024
            )
          ]
        )
      end)

      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent"
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => false,
                 "name" => "z.log",
                 "path" => "agent/z.log",
                 "size" => 128
               },
               %{
                 "is_directory" => false,
                 "name" => "a.log",
                 "path" => "agent/a.log",
                 "size" => 256
               },
               %{
                 "is_directory" => false,
                 "name" => "job_logs.txt.gz",
                 "path" => "agent/job_logs.txt.gz",
                 "size" => 1024
               }
             ]
    end

    test "normalizes directory path with trailing slash from backend", ctx do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _ ->
        InternalApi.Artifacthub.ListPathResponse.new(
          items: [
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/jobs/#{ctx.job.id}/agent/",
              is_directory: true,
              size: 0
            )
          ]
        )
      end)

      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "agent",
                 "path" => "agent"
               }
             ]
    end

    test "forces unwrap_directories=false in artifacthub list_path request", ctx do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn req, _ ->
        assert req.unwrap_directories == false

        InternalApi.Artifacthub.ListPathResponse.new(
          items: [
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/jobs/#{ctx.job.id}/agent/",
              is_directory: true,
              size: 0
            )
          ]
        )
      end)

      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "agent",
                 "path" => "agent"
               }
             ]
    end

    test "returns 404 when backend list contains out-of-scope path", ctx do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _ ->
        InternalApi.Artifacthub.ListPathResponse.new(
          items: [
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/workflows/some-other-id/secret.txt",
              is_directory: false,
              size: 123
            )
          ]
        )
      end)

      assert {404, "Artifact path not found"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id
               )
    end

    test "returns 404 when backend list contains traversal segments under valid scope", ctx do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _ ->
        InternalApi.Artifacthub.ListPathResponse.new(
          items: [
            InternalApi.Artifacthub.ListItem.new(
              name: "artifacts/jobs/#{ctx.job.id}/agent/../secret.txt",
              is_directory: false,
              size: 123
            )
          ]
        )
      end)

      assert {404, "Artifact path not found"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id
               )
    end

    test "returns 400 when backend reports path exceeds hard limit", ctx do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _ ->
        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "path resolves to too many files; narrow the path"
      end)

      assert {400, "path resolves to too many files; narrow the path"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id
               )
    end

    test "ignores unwrap_directories query param from user input", ctx do
      assert {200, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "unwrap_directories" => "true"
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "agent",
                 "path" => "agent"
               }
             ]
    end

    test "resolves project_id from job scope_id even when request includes another project_id",
         ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)
      {_workflow, other_job} = create_workflow_and_job(other_project, ctx.user.id, ctx.org.id)

      Support.Stubs.Artifacthub.create(other_job.id,
        scope: "jobs",
        path: "agent/other_job_logs.txt.gz",
        url: "https://localhost:9000/agent/other_job_logs.txt.gz"
      )

      assert {200, response} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "jobs",
                   "scope_id" => other_job.id
                 },
                 ctx.user.id,
                 true
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "agent",
                 "path" => "agent"
               }
             ]
    end

    test "resolves project_id from workflow scope_id even when request includes another project_id",
         ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)

      {other_workflow, _other_job} =
        create_workflow_and_job(other_project, ctx.user.id, ctx.org.id)

      Support.Stubs.Artifacthub.create(other_workflow.wf_id,
        scope: "workflows",
        path: "debug/other_workflow_logs.txt",
        url: "https://localhost:9000/debug/other_workflow_logs.txt"
      )

      assert {200, response} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "workflows",
                   "scope_id" => other_workflow.wf_id
                 },
                 ctx.user.id,
                 true
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "debug",
                 "path" => "debug"
               }
             ]
    end

    test "resolves project_id from project scope_id even when request includes another project_id",
         ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)

      Support.Stubs.Artifacthub.create(other_project.id,
        scope: "projects",
        path: "other/releases.tar.gz",
        url: "https://localhost:9000/other/releases.tar.gz"
      )

      assert {200, response} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "projects",
                   "scope_id" => other_project.id
                 },
                 ctx.user.id,
                 true
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "other",
                 "path" => "other"
               }
             ]
    end

    test "returns 400 for invalid scope", ctx do
      assert {400, "scope must be one of: projects, workflows, jobs"} =
               list_artifacts(
                 %{
                   "scope" => "invalid",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 400 for path traversal", ctx do
      assert {400, "path traversal is not allowed"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "../agent"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 400 for double-encoded traversal in raw query path", ctx do
      query =
        "scope=jobs&scope_id=#{ctx.job.id}&path=%252e%252e%252fprojects%252f#{ctx.project.id}%252fsecret.txt"

      assert {400, "path traversal is not allowed"} =
               list_artifacts_raw(query, ctx.user.id, false)
    end

    test "returns 400 for double-encoded backslash traversal in raw query path", ctx do
      query = "scope=jobs&scope_id=#{ctx.job.id}&path=agent%255c..%255csecret.txt"

      assert {400, body} = list_artifacts_raw(query, ctx.user.id, false)
      assert body in ["invalid path", "path traversal is not allowed"]
    end

    test "returns 401 when user has no project.view permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, "Permission denied"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 401 when user has no project.artifacts.view permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.artifacts.view")
        )
      end)

      assert {401, "Permission denied"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 404 on project/org mismatch", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      project = Support.Stubs.Project.create(org, ctx.user)
      {_workflow, other_job} = create_workflow_and_job(project, ctx.user.id, org.id)

      assert {404, "Not found"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => other_job.id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 500 when artifact store is not configured", ctx do
      set_project_artifact_store_id(ctx.project, "")

      assert {500, response} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false
               )

      assert response =~ "Artifact store is not configured"
    end

    test "returns 403 when artifacts api feature is disabled", ctx do
      org_id_without_feature = UUID.uuid4()
      Support.Stubs.Feature.set_org_defaults(org_id_without_feature)
      Support.Stubs.Feature.disable_feature(org_id_without_feature, :artifacts_api)

      assert {403,
              "The artifacts api feature is not enabled for your organization. Please contact support"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false,
                 org_id_without_feature
               )
    end

    test "returns 403 when artifacts feature is disabled", ctx do
      org_id_without_artifacts = UUID.uuid4()
      Support.Stubs.Feature.set_org_defaults(org_id_without_artifacts)
      Support.Stubs.Feature.enable_feature(org_id_without_artifacts, :artifacts_api)
      Support.Stubs.Feature.disable_feature(org_id_without_artifacts, :artifacts)

      assert {403,
              "The artifacts api feature is not enabled for your organization. Please contact support"} =
               list_artifacts(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false,
                 org_id_without_artifacts
               )
    end

    test "returns 403 when org header is missing", ctx do
      assert {403,
              "The artifacts api feature is not enabled for your organization. Please contact support"} =
               list_artifacts_raw(
                 URI.encode_query(%{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 }),
                 ctx.user.id,
                 false,
                 headers_without_org(ctx.user.id)
               )
    end
  end

  defp list_artifacts(
         params,
         user_id,
         decode? \\ true,
         org_id \\ Support.Stubs.Organization.default_org_id()
       ) do
    params
    |> URI.encode_query()
    |> list_artifacts_raw(user_id, decode?, headers(user_id, org_id))
  end

  defp headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp headers_without_org(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id}
    ]

  defp list_artifacts_raw(query, user_id, decode?) do
    list_artifacts_raw(query, user_id, decode?, nil)
  end

  defp list_artifacts_raw(query, user_id, decode?, request_headers) do
    request_headers =
      request_headers || headers(user_id, Support.Stubs.Organization.default_org_id())

    url = "localhost:4004/artifacts?" <> query

    {:ok, response} = HTTPoison.get(url, request_headers)
    %{body: body, status_code: status_code} = response

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp create_workflow_and_job(project, user_id, org_id) do
    build_req_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}

    workflow = Workflow.create(hook, user_id, organization_id: org_id)
    pipeline = Pipeline.create_initial(workflow)

    _block =
      Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"],
        build_req_id: build_req_id
      })

    job = Job.create(pipeline.id, build_req_id, project_id: project.id)

    {workflow.api_model, job.api_model}
  end

  defp set_project_artifact_store_id(project, artifact_store_id) do
    updated_project = %{
      project
      | api_model: %{
          project.api_model
          | spec: %{project.api_model.spec | artifact_store_id: artifact_store_id}
        }
    }

    Support.Stubs.DB.update(:projects, updated_project)
  end
end
