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
                   "project_id" => ctx.project.id,
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "agent",
                 "path" => "agent",
                 "size" => 0
               }
             ]
    end

    test "returns 200 and workflow artifacts root listing", ctx do
      assert {200, response} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "workflows",
                   "scope_id" => ctx.workflow.wf_id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "debug",
                 "path" => "debug",
                 "size" => 0
               }
             ]
    end

    test "returns 200 and project artifacts root listing", ctx do
      assert {200, response} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "projects",
                   "scope_id" => ctx.project.id
                 },
                 ctx.user.id
               )

      assert response["artifacts"] == [
               %{
                 "is_directory" => true,
                 "name" => "releases",
                 "path" => "releases",
                 "size" => 0
               }
             ]
    end

    test "returns 200 and nested listing for a specific path", ctx do
      assert {200, response} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
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
                 "size" => 0
               }
             ]
    end

    test "returns paginated response using limit parameter", ctx do
      Support.Stubs.Artifacthub.create(ctx.job.id,
        scope: "jobs",
        path: "agent/extra.log",
        url: "https://localhost:9000/agent/extra.log"
      )

      assert {200, response} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "agent",
                   "limit" => "1"
                 },
                 ctx.user.id
               )

      assert length(response["artifacts"]) == 1

      assert response["page"] == %{
               "limit" => 1,
               "returned" => 1,
               "total" => 2,
               "truncated" => true
             }
    end

    test "returns 400 for invalid limit", ctx do
      assert {400, "limit must be an integer between 1 and 1000"} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "limit" => "0"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 404 when project scope_id belongs to a different project", ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)

      Support.Stubs.Artifacthub.create(other_project.id,
        scope: "projects",
        path: "other/releases.tar.gz",
        url: "https://localhost:9000/other/releases.tar.gz"
      )

      assert {404, "Not found"} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "projects",
                   "scope_id" => other_project.id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 404 when job scope_id belongs to a different project", ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)
      {_workflow, other_job} = create_workflow_and_job(other_project, ctx.user.id, ctx.org.id)

      Support.Stubs.Artifacthub.create(other_job.id,
        scope: "jobs",
        path: "agent/other_job_logs.txt.gz",
        url: "https://localhost:9000/agent/other_job_logs.txt.gz"
      )

      assert {404, "Not found"} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "jobs",
                   "scope_id" => other_job.id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 404 when workflow scope_id belongs to a different project", ctx do
      other_project = Support.Stubs.Project.create(ctx.org, ctx.user)
      {other_workflow, _job} = create_workflow_and_job(other_project, ctx.user.id, ctx.org.id)

      Support.Stubs.Artifacthub.create(other_workflow.wf_id,
        scope: "workflows",
        path: "debug/other_workflow_logs.txt",
        url: "https://localhost:9000/debug/other_workflow_logs.txt"
      )

      assert {404, "Not found"} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
                   "scope" => "workflows",
                   "scope_id" => other_workflow.wf_id
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 400 for invalid scope", ctx do
      assert {400, "scope must be one of: projects, workflows, jobs"} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
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
                   "project_id" => ctx.project.id,
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id,
                   "path" => "../agent"
                 },
                 ctx.user.id,
                 false
               )
    end

    test "returns 401 when user has no artifact permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.artifacts.view")
        )
      end)

      assert {401, "Permission denied"} =
               list_artifacts(
                 %{
                   "project_id" => ctx.project.id,
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

      assert {404, "Not found"} =
               list_artifacts(
                 %{
                   "project_id" => project.id,
                   "scope" => "jobs",
                   "scope_id" => ctx.job.id
                 },
                 ctx.user.id,
                 false
               )
    end
  end

  defp list_artifacts(params, user_id, decode? \\ true) do
    url = "localhost:4004/artifacts?" <> URI.encode_query(params)

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
end
