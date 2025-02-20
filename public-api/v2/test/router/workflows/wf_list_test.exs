defmodule Router.Workflows.ListTest do
  use PublicAPI.Case

  setup do
    Support.Stubs.reset()
  end

  describe "authorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project_id)

      {:ok, %{project_id: project_id, org_id: org_id, user_id: user_id}}
    end

    test "GET /workflows/ - endpoint returns 200", ctx do
      project_id = ctx.project_id
      hook = %{id: UUID.uuid4(), project_id: project_id, branch_id: UUID.uuid4()}

      _ =
        Support.Stubs.Workflow.create(hook, UUID.uuid4(),
          branch_name: "master",
          organization_id: ctx.org_id
        )

      _ =
        Support.Stubs.Workflow.create(hook, UUID.uuid4(),
          branch_name: "staging",
          organization_id: ctx.org_id
        )

      # Older workflow is listed first
      wf3 =
        Support.Stubs.Workflow.create(hook, UUID.uuid4(),
          branch_name: "staging",
          created_at: DateTime.to_unix(DateTime.utc_now()) + 100,
          organization_id: ctx.org_id
        )

      wf3_id = wf3.id

      created_before =
        DateTime.utc_now() |> Timex.shift(days: -2) |> Timex.format!("{ISO:Extended:Z}")

      created_after =
        DateTime.utc_now() |> Timex.shift(days: -2) |> Timex.format!("{ISO:Extended:Z}")

      params = %{
        project_id: project_id,
        branch_name: "staging",
        created_before: created_before,
        created_after: created_after,
        page_size: 1
      }

      assert {200, _headers, result} = list_wfs(ctx, params)

      assert [%{"wf_id" => ^wf3_id}] = result
    end

    test "GET with created_before - cast timestamp into proper value", ctx do
      project_id = ctx.project_id
      hook = %{id: UUID.uuid4(), project_id: project_id, branch_id: UUID.uuid4()}

      # Older workflow is listed first
      wf =
        Support.Stubs.Workflow.create(hook, UUID.uuid4(),
          branch_name: "staging",
          created_at: DateTime.to_unix(DateTime.utc_now()) + 100
        )

      wf_id = wf.id
      timestamp = DateTime.utc_now() |> Timex.format!("{ISO:Extended:Z}")

      created_before =
        DateTime.utc_now() |> Timex.shift(seconds: 101) |> Timex.format!("{ISO:Extended:Z}")

      params = %{
        project_id: project_id,
        page_size: 1,
        created_after: timestamp,
        created_before: created_before
      }

      assert {200, _headers, result} = list_wfs(ctx, params)

      assert [%{"wf_id" => ^wf_id}] = result
    end

    test "GET fails when returned list contains a workflow not owned by requester org", ctx do
      project_id = ctx.project_id
      hook = %{id: UUID.uuid4(), project_id: project_id, branch_id: UUID.uuid4()}

      # Older workflow is listed first
      wf =
        Support.Stubs.Workflow.create(hook, UUID.uuid4(),
          branch_name: "staging",
          created_at: DateTime.to_unix(DateTime.utc_now()) + 100
        )

      timestamp = DateTime.utc_now() |> Timex.format!("{ISO:Extended:Z}")

      created_before =
        DateTime.utc_now() |> Timex.shift(seconds: 101) |> Timex.format!("{ISO:Extended:Z}")

      params = %{
        project_id: project_id,
        page_size: 1,
        created_after: timestamp,
        created_before: created_before
      }

      GrpcMock.stub(WorkflowMock, :list_keyset, fn _req, _ ->
        alias InternalApi.PlumberWF.ListKeysetResponse
        # workflow = workflow.api_model
        %ListKeysetResponse{
          status: %InternalApi.Status{},
          workflows: [%{wf.api_model | project_id: UUID.uuid4()}]
        }
      end)

      assert {404, _headers, _result} = list_wfs(ctx, params)
    end
  end

  def list_wfs(ctx, params, decode? \\ true) do
    {:ok, response} = get_list_wfs(ctx, params)
    %{:body => body, :status_code => status_code, headers: headers} = response
    require Logger
    Logger.debug("Response body: #{inspect(body)}")
    Logger.debug("Headers: #{inspect(headers)}")

    body =
      case decode? do
        true -> Jason.decode!(body)
        false -> body
      end

    {status_code, headers, body}
  end

  defp get_list_wfs(ctx, params) do
    url = url() <> "/workflows?" <> Plug.Conn.Query.encode(params)
    HTTPoison.get(url, headers(ctx))
  end
end
