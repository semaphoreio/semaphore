defmodule Router.Trobleshoot.Workflow.Test do
  use ExUnit.Case

  alias Support.Stubs.{Pipeline, Workflow}

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    user_id = user.id
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Workflow.create(hook, user_id, organization_id: org.id)
    _ = Pipeline.create_initial(workflow)

    %{user: user, user_id: user_id, wf: workflow.api_model}
  end

  describe "GET /troubleshoot/workflow/:wf_id" do
    test "project ID mismatch", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      project = Support.Stubs.Project.create(org, ctx.user)
      hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}

      workflow = Workflow.create(hook, ctx.user_id, organization_id: org.id)
      pipeline = Pipeline.create_initial(workflow)

      Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"]
      })

      assert {404, _} = troubleshoot_workflow(workflow.id, ctx.user_id, false)
    end

    test "unauthorized user", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {404, _} = troubleshoot_workflow(ctx.wf.wf_id, ctx.user_id, false)
    end

    test "returns 404 for pipeline that does not exist", ctx do
      non_existing_wf_id = UUID.uuid4()
      assert {404, _} = troubleshoot_workflow(non_existing_wf_id, ctx.user_id, false)
    end

    test "returns 200 and troubleshoot data for existing pipeline", ctx do
      assert {200, response} = troubleshoot_workflow(ctx.wf.wf_id, ctx.user_id)

      assert response == %{
               "project" => %{
                 "id" => ctx.wf.project_id,
                 "organization_id" => ctx.wf.organization_id
               },
               "workflow" => %{
                 "branch_id" => ctx.wf.branch_id,
                 "branch_name" => "master",
                 "commit_sha" => ctx.wf.commit_sha,
                 "created_at" => to_datetime(ctx.wf.created_at),
                 "hook_id" => ctx.wf.hook_id,
                 "initial_ppl_id" => ctx.wf.initial_ppl_id,
                 "repository_id" => "",
                 "requester_id" => ctx.wf.requester_id,
                 "rerun_of" => "",
                 "triggered_by" => "hook",
                 "wf_id" => ctx.wf.wf_id
               }
             }
    end
  end

  defp troubleshoot_workflow(wf_id, user_id, decode? \\ true) do
    url = "localhost:4004/troubleshoot/workflow/" <> wf_id
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

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

  def to_datetime(%{nanos: 0, seconds: 0}), do: ""

  def to_datetime(%{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    DateTime.to_string(ts_date_time)
  end
end
