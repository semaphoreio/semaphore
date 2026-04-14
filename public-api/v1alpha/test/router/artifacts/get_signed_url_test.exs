defmodule PipelinesAPI.Artifacts.GetSignedURLTest do
  use ExUnit.Case

  alias Support.Stubs.{Job, Pipeline, Workflow}

  @max_items PipelinesAPI.ArtifactHubClient.max_items()

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
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
      url: artifact_url("jobs", job.api_model.id, "agent/job_logs.txt.gz")
    )

    Support.Stubs.Artifacthub.create(workflow.api_model.wf_id,
      scope: "workflows",
      path: "debug/workflow_logs.txt",
      url: artifact_url("workflows", workflow.api_model.wf_id, "debug/workflow_logs.txt")
    )

    Support.Stubs.Artifacthub.create(project.id,
      scope: "projects",
      path: "releases/build.tar.gz",
      url: artifact_url("projects", project.id, "releases/build.tar.gz")
    )

    {:ok,
     %{org: org, user: user, project: project, workflow: workflow.api_model, job: job.api_model}}
  end

  describe "GET /artifacts/signed_url" do
    test "returns 200 and a signed URL for job artifact", ctx do
      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz"
                 },
                 ctx.user.id
               )

      assert_single_item_response(
        response,
        "agent/job_logs.txt.gz",
        artifact_url("jobs", ctx.job.id, "agent/job_logs.txt.gz")
      )
    end

    test "returns 200 and a signed URL for workflow artifact", ctx do
      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "workflows",
                   "scope_id" => ctx.workflow.wf_id,
                   "path" => "debug/workflow_logs.txt"
                 },
                 ctx.user.id
               )

      assert_single_item_response(
        response,
        "debug/workflow_logs.txt",
        artifact_url("workflows", ctx.workflow.wf_id, "debug/workflow_logs.txt")
      )
    end

    test "returns 200 and a signed URL for project artifact", ctx do
      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "projects",
                   "scope_id" => ctx.project.id,
                   "path" => "releases/build.tar.gz"
                 },
                 ctx.user.id
               )

      assert_single_item_response(
        response,
        "releases/build.tar.gz",
        artifact_url("projects", ctx.project.id, "releases/build.tar.gz")
      )
    end

    test "returns 200 and accepts HEAD method", ctx do
      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz",
                   "method" => "HEAD"
                 },
                 ctx.user.id
               )

      assert_single_item_response(
        response,
        "agent/job_logs.txt.gz",
        artifact_url("jobs", ctx.job.id, "agent/job_logs.txt.gz")
      )
    end

    test "returns recursively signed URLs for a directory", ctx do
      Support.Stubs.Artifacthub.create(ctx.job.id,
        scope: "jobs",
        path: "logs/a.log",
        url: artifact_url("jobs", ctx.job.id, "logs/a.log")
      )

      Support.Stubs.Artifacthub.create(ctx.job.id,
        scope: "jobs",
        path: "logs/sub/b.log",
        url: artifact_url("jobs", ctx.job.id, "logs/sub/b.log")
      )

      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "logs"
                 },
                 ctx.user.id
               )

      assert response == %{
               "items" => [
                 %{
                   "path" => "logs/a.log",
                   "url" => artifact_url("jobs", ctx.job.id, "logs/a.log")
                 },
                 %{
                   "path" => "logs/sub/b.log",
                   "url" => artifact_url("jobs", ctx.job.id, "logs/sub/b.log")
                 }
               ]
             }
    end

    test "preserves backend order for directory signed URLs", ctx do
      GrpcMock.stub(ArtifacthubMock, :get_signed_urls, fn _req, _ ->
        InternalApi.Artifacthub.GetSignedURLSResponse.new(
          urls: [
            InternalApi.Artifacthub.SignedURL.new(
              url: "https://localhost:9000/artifacts/jobs/#{ctx.job.id}/logs/z.log",
              method: InternalApi.Artifacthub.SignedURL.Method.value(:GET)
            ),
            InternalApi.Artifacthub.SignedURL.new(
              url: "https://localhost:9000/artifacts/jobs/#{ctx.job.id}/logs/a.log",
              method: InternalApi.Artifacthub.SignedURL.Method.value(:GET)
            )
          ]
        )
      end)

      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "logs"
                 },
                 ctx.user.id
               )

      assert response == %{
               "items" => [
                 %{
                   "path" => "logs/z.log",
                   "url" => "https://localhost:9000/artifacts/jobs/#{ctx.job.id}/logs/z.log"
                 },
                 %{
                   "path" => "logs/a.log",
                   "url" => "https://localhost:9000/artifacts/jobs/#{ctx.job.id}/logs/a.log"
                 }
               ]
             }
    end

    test "sends hard item limit to backend", ctx do
      GrpcMock.stub(ArtifacthubMock, :get_signed_urls, fn req, _ ->
        assert req.limit == @max_items

        InternalApi.Artifacthub.GetSignedURLSResponse.new(
          urls: [
            InternalApi.Artifacthub.SignedURL.new(
              url: "https://localhost:9000/artifacts/jobs/#{ctx.job.id}/agent/job_logs.txt.gz",
              method: InternalApi.Artifacthub.SignedURL.Method.value(:GET)
            )
          ]
        )
      end)

      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz"
                 },
                 ctx.user.id
               )

      assert_single_item_response(
        response,
        "agent/job_logs.txt.gz",
        artifact_url("jobs", ctx.job.id, "agent/job_logs.txt.gz")
      )
    end

    test "returns 500 when backend directory URL does not contain expected artifact marker",
         ctx do
      Support.Stubs.Artifacthub.create(ctx.job.id,
        scope: "jobs",
        path: "logs/a.log",
        url: artifact_url("jobs", ctx.job.id, "logs/a.log")
      )

      Support.Stubs.Artifacthub.create(ctx.job.id,
        scope: "jobs",
        path: "logs/sub/b.log",
        url: artifact_url("jobs", ctx.job.id, "logs/sub/b.log")
      )

      GrpcMock.stub(ArtifacthubMock, :get_signed_urls, fn req, _ ->
        InternalApi.Artifacthub.GetSignedURLSResponse.new(
          urls: [
            InternalApi.Artifacthub.SignedURL.new(
              url: "https://localhost:9000/" <> Path.basename(req.path),
              method: InternalApi.Artifacthub.SignedURL.Method.value(:GET)
            )
          ]
        )
      end)

      assert {500, "Internal error"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "logs"
                 },
                 ctx.user.id
               )
    end

    test "returns 500 when backend file URL does not contain expected artifact marker", ctx do
      Support.Stubs.Artifacthub.create(ctx.job.id,
        scope: "jobs",
        path: "logs/a.log",
        url: artifact_url("jobs", ctx.job.id, "logs/a.log")
      )

      GrpcMock.stub(ArtifacthubMock, :get_signed_urls, fn req, _ ->
        InternalApi.Artifacthub.GetSignedURLSResponse.new(
          urls: [
            InternalApi.Artifacthub.SignedURL.new(
              url: "https://localhost:9000/" <> Path.basename(req.path),
              method: InternalApi.Artifacthub.SignedURL.Method.value(:GET)
            )
          ]
        )
      end)

      assert {500, "Internal error"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "logs/missing.log"
                 },
                 ctx.user.id
               )
    end

    test "returns 404 when backend signed URL path resolves to scope root", ctx do
      GrpcMock.stub(ArtifacthubMock, :get_signed_urls, fn _req, _ ->
        InternalApi.Artifacthub.GetSignedURLSResponse.new(
          urls: [
            InternalApi.Artifacthub.SignedURL.new(
              url: "https://localhost:9000/artifacts/jobs/#{ctx.job.id}/",
              method: InternalApi.Artifacthub.SignedURL.Method.value(:GET)
            )
          ]
        )
      end)

      assert {404, "Artifact not found"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "logs"
                 },
                 ctx.user.id
               )
    end

    test "passes HEAD method through to backend for directories", ctx do
      assert {200, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent",
                   "method" => "HEAD"
                 },
                 ctx.user.id
               )

      assert_single_item_response(
        response,
        "agent/job_logs.txt.gz",
        artifact_url("jobs", ctx.job.id, "agent/job_logs.txt.gz")
      )
    end

    test "resolves project_id from job scope_id even when request includes another project_id",
         ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)
      {_workflow, other_job} = create_workflow_and_job(other_project, ctx.user.id, ctx.org.id)

      Support.Stubs.Artifacthub.create(other_job.id,
        scope: "jobs",
        path: "agent/other_job_logs.txt.gz",
        url: artifact_url("jobs", other_job.id, "agent/other_job_logs.txt.gz")
      )

      assert {200, response} =
               signed_url(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "jobs",
                   "scope_id" => other_job.id,
                   "path" => "agent/other_job_logs.txt.gz"
                 },
                 ctx.user.id,
                 true
               )

      assert_single_item_response(
        response,
        "agent/other_job_logs.txt.gz",
        artifact_url("jobs", other_job.id, "agent/other_job_logs.txt.gz")
      )
    end

    test "resolves project_id from workflow scope_id even when request includes another project_id",
         ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)

      {other_workflow, _other_job} =
        create_workflow_and_job(other_project, ctx.user.id, ctx.org.id)

      Support.Stubs.Artifacthub.create(other_workflow.wf_id,
        scope: "workflows",
        path: "debug/other_workflow_logs.txt",
        url: artifact_url("workflows", other_workflow.wf_id, "debug/other_workflow_logs.txt")
      )

      assert {200, response} =
               signed_url(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "workflows",
                   "scope_id" => other_workflow.wf_id,
                   "path" => "debug/other_workflow_logs.txt"
                 },
                 ctx.user.id,
                 true
               )

      assert_single_item_response(
        response,
        "debug/other_workflow_logs.txt",
        artifact_url("workflows", other_workflow.wf_id, "debug/other_workflow_logs.txt")
      )
    end

    test "resolves project_id from project scope_id even when request includes another project_id",
         ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)

      Support.Stubs.Artifacthub.create(other_project.id,
        scope: "projects",
        path: "other/releases.tar.gz",
        url: artifact_url("projects", other_project.id, "other/releases.tar.gz")
      )

      assert {200, response} =
               signed_url(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "projects",
                   "scope_id" => other_project.id,
                   "path" => "other/releases.tar.gz"
                 },
                 ctx.user.id,
                 true
               )

      assert_single_item_response(
        response,
        "other/releases.tar.gz",
        artifact_url("projects", other_project.id, "other/releases.tar.gz")
      )
    end

    test "returns 404 on project/org mismatch", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      project = Support.Stubs.Project.create(org, ctx.user)
      {_workflow, other_job} = create_workflow_and_job(project, ctx.user.id, org.id)

      Support.Stubs.Artifacthub.create(other_job.id,
        scope: "jobs",
        path: "agent/other_job_logs.txt.gz",
        url: artifact_url("jobs", other_job.id, "agent/other_job_logs.txt.gz")
      )

      assert {404, "Not found"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => other_job.id,
                   "path" => "agent/other_job_logs.txt.gz"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 404 when signed URL path does not exist", ctx do
      assert {404, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/missing.log"
                 },
                 ctx.user.id
               )

      assert response == "Artifact not found"
    end

    test "returns 400 when path is missing", ctx do
      assert {400, "path must be present"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 400 when scope is invalid even if scope_id is an existing job", ctx do
      assert {400, "scope must be one of: projects, workflows, jobs"} =
               signed_url(
                 %{
                   "scope" => "pipelines",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 400 when method is invalid", ctx do
      assert {400, "method must be one of: GET, HEAD"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz",
                   "method" => "DELETE"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 400 when method has invalid type", ctx do
      base_query =
        URI.encode_query(%{
          "scope" => "jobs",
          "scope_id" => ctx.job.id,
          "path" => "agent/job_logs.txt.gz"
        })

      assert {400, "method must be one of: GET, HEAD"} =
               signed_url_raw(base_query <> "&method[]=GET", ctx.user.id, false)
    end

    test "returns 400 when backend reports path exceeds hard limit", ctx do
      GrpcMock.stub(ArtifacthubMock, :get_signed_urls, fn req, _ ->
        assert req.limit == @max_items

        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "path resolves to too many files; narrow the path"
      end)

      assert {400, "path resolves to too many files; narrow the path"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent"
                 },
                 ctx.user.id
               )
    end

    test "returns 401 when user has no artifact permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.artifacts.view")
        )
      end)

      assert {401, "Permission denied"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 401 when user has no project.view permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, "Permission denied"} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 500 when artifact store is not configured", ctx do
      set_project_artifact_store_id(ctx.project, "")

      assert {500, response} =
               signed_url(
                 %{
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent/job_logs.txt.gz"
                 },
                 ctx.user.id
               )

      assert response =~ "Artifact store is not configured"
    end
  end

  defp signed_url(params, user_id, decode? \\ true) do
    params
    |> URI.encode_query()
    |> signed_url_raw(user_id, decode?)
  end

  defp signed_url_raw(query, user_id, decode?) do
    url = "localhost:4004/artifacts/signed_url?" <> query

    {:ok, response} = HTTPoison.get(url, headers(user_id))
    %{body: body, status_code: status_code} = response

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]

  defp assert_single_item_response(response, path, url) do
    assert response == %{
             "items" => [
               %{"path" => path, "url" => url}
             ]
           }
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

  defp artifact_url(scope, scope_id, path) do
    "https://localhost:9000/artifacts/#{scope}/#{scope_id}/#{String.trim_leading(path, "/")}"
  end
end
