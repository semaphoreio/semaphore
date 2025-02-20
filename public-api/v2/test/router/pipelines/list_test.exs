defmodule Router.ListTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project_id)

      created_after =
        DateTime.utc_now() |> Timex.shift(seconds: -10) |> Timex.format!("{ISO:Extended:Z}")

      created_before =
        DateTime.utc_now() |> Timex.shift(seconds: 1) |> Timex.format!("{ISO:Extended:Z}")

      {:ok,
       %{
         project_id: project_id,
         org_id: org_id,
         user_id: user_id,
         created_after: created_after,
         created_before: created_before
       }}
    end

    test "GET /pipelines - endpoint returns paginated ppls (correct headers set)", ctx do
      project_id = ctx.project_id
      hook_id = UUID.uuid4()
      hook = %{id: hook_id, project_id: project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      workflow_id = workflow.id

      pipeline =
        Support.Stubs.Pipeline.create_initial(workflow,
          name: "Pipeline #1",
          commit_sha: "75891a4469488cb714b6931bfd63ecb71180f7ad",
          working_directory: ".semaphore",
          yaml_file_name: "semaphore.yml"
        )

      pipeline_id = pipeline.id
      assert {200, _headers, list_res} = list_ppls_from(project_id, ctx)

      assert [
               %{
                 "commit_sha" => "75891a4469488cb714b6931bfd63ecb71180f7ad",
                 "created_at" => _,
                 "done_at" => _,
                 "pending_at" => _,
                 "queuing_at" => _,
                 "running_at" => _,
                 "stopping_at" => _,
                 "error_description" => "",
                 "name" => "Pipeline #1",
                 "state" => "QUEUING",
                 "terminate_request" => "",
                 "terminated_by" => nil,
                 "working_directory" => ".semaphore",
                 "yaml_file_name" => "semaphore.yml",
                 "branch_id" => _,
                 "hook_id" => ^hook_id,
                 "ppl_id" => ^pipeline_id,
                 "project_id" => ^project_id,
                 "wf_id" => ^workflow_id
               }
             ] = list_res
    end

    test "GET /pipelines - params: wf_id and no project_id", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      _ = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      assert {200, _headers, _list_res} = list_ppls(workflow.id, ctx)
    end

    test "GET /pipelines - no wf_id with and no project_id", ctx do
      {:ok, response} = HTTPoison.get(url() <> "/pipelines?", headers(ctx))
      %{:body => body, :status_code => status_code} = response
      body = Jason.decode!(body)
      assert {%{"message" => "Validation Failed"}, 422} = {body, status_code}
    end

    test "GET /pipelines - no created_after and created_before -> returns validation error",
         ctx do
      project_id = ctx.project_id
      hook_id = UUID.uuid4()
      hook = %{id: hook_id, project_id: project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())

      Support.Stubs.Pipeline.create_initial(workflow,
        name: "Pipeline #1",
        commit_sha: "75891a4469488cb714b6931bfd63ecb71180f7ad",
        working_directory: ".semaphore",
        yaml_file_name: "semaphore.yml"
      )

      ctx = ctx |> Map.merge(%{created_after: nil, created_before: nil})

      assert {422, _, resp} = list_ppls_from(project_id, ctx)
      assert "Validation Failed" == resp["message"]
    end

    test "GET /pipelines - resource is not owned by requester -> 404", ctx do
      wrong_org = UUID.uuid4()
      wrong_project_id = UUID.uuid4()

      wrong_project =
        Support.Stubs.Project.create(%{id: wrong_org}, %{id: ctx.user_id}, id: wrong_project_id)

      hook_id = UUID.uuid4()
      hook = %{id: hook_id, project_id: wrong_project.id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())

      pipeline =
        Support.Stubs.Pipeline.create_initial(workflow,
          name: "Pipeline #1",
          commit_sha: "75891a4469488cb714b6931bfd63ecb71180f7ad",
          working_directory: ".semaphore",
          yaml_file_name: "semaphore.yml"
        )

      GrpcMock.stub(PipelineMock, :list_keyset, fn _req, _ ->
        %InternalApi.Plumber.ListKeysetResponse{
          pipelines: [pipeline],
          next_page_token: "asdf",
          previous_page_token: ""
        }
      end)

      assert {404, _headers, res} = list_ppls_from(ctx.project_id, ctx)
      assert "Not found" == res["message"]
    end
  end

  defp list_ppls(wf_id, ctx, decode? \\ true) do
    params = %{wf_id: wf_id, created_after: ctx.created_after, created_before: ctx.created_before}
    {:ok, response} = get_list_ppls(ctx, params)
    %{body: body, status_code: status_code, headers: headers} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))

    body =
      case decode? do
        true -> Jason.decode!(body)
        false -> body
      end

    {status_code, headers, body}
  end

  defp list_ppls_from(project_id, ctx) do
    params = %{
      project_id: project_id,
      created_after: ctx.created_after,
      created_before: ctx.created_before
    }

    {:ok, response} = get_list_ppls(ctx, params)
    %{body: body, status_code: status_code, headers: headers} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))
    {status_code, headers, Jason.decode!(body)}
  end

  defp get_list_ppls(ctx, params) do
    url = url() <> "/pipelines?" <> Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx))
  end
end
