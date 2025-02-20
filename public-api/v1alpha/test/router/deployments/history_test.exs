defmodule Router.Deployments.HistoryTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    Support.Stubs.Feature.enable_feature(org.id, :deployment_targets)

    {:ok,
     extra_args: %{
       "organization_id" => org.id,
       "project_id" => project.id,
       "requester_id" => user.id
     }}
  end

  describe "GET /deployment_targets/:target_id/history - endpoint returns list of deployments" do
    setup [:setup_deployment_target, :setup_common_args]

    test "when project ID mismatches then returns 404", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      user = Support.Stubs.User.create_default()
      project = Support.Stubs.Project.create(org, user)

      {target, _secret} =
        Support.Stubs.Deployments.create(project, user, "target1", %{
          env_vars: [%{name: "X", value: "123"}],
          files: [%{path: "/lib/code.ex", content: "abc"}]
        })

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args["project_id"]
      }

      assert {404, _headers, "Not found"} = get_history(%{ctx | target: target}, params)

      assert {404, _headers, "Not found"} =
               get_history(%{ctx | target: target}, %{"target_id" => target.id})
    end

    test "request list of deployment targets history and get :ok response", ctx do
      ctx
      |> add_pipeline_promotion("Production", :STARTED, :passed)
      |> add_pipeline_promotion("Production", :STARTED, :failed)
      |> add_pipeline_promotion("Production", :FAILED, :failed)
      |> add_pipeline_promotion("Production", :PENDING, nil)

      params = %{
        "cursor_type" => 0,
        "cursor_value" => 0,
        "git_ref_type" => "branch",
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, body} = get_history(ctx, params)

      assert status_code == 200
      assert deployments = body["deployments"]
      assert length(deployments) == 4

      assert ["PENDING", "FAILED", "STARTED", "STARTED"] =
               Enum.map(deployments, fn dep -> dep["state"] end)
    end

    test "request list of deployment targets history and project_id is missing and get :ok response",
         ctx do
      ctx
      |> add_pipeline_promotion("Production", :STARTED, :passed)
      |> add_pipeline_promotion("Production", :STARTED, :failed)
      |> add_pipeline_promotion("Production", :FAILED, :failed)
      |> add_pipeline_promotion("Production", :PENDING, nil)

      params = %{
        "cursor_type" => 0,
        "cursor_value" => 0,
        "git_ref_type" => "branch"
      }

      {status_code, _headers, body} = get_history(ctx, params)
      assert status_code == 200
      assert deployments = body["deployments"]
      assert length(deployments) == 4

      assert ["PENDING", "FAILED", "STARTED", "STARTED"] =
               Enum.map(deployments, fn dep -> dep["state"] end)
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.view")
        )
      end)

      params = %{
        "target_id" => ctx.target_id,
        "cursor_type" => 0,
        "cursor_value" => 0,
        "git_ref_type" => "branch",
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = get_history(ctx, params)
      assert status_code == 401
      assert message == "Permission denied"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))

      params = %{
        "target_id" => ctx.target_id,
        "project_id" => ctx.extra_args["project_id"]
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      {status_code, _headers, message} = get_history(ctx, params)
      assert status_code == 403

      assert message ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end
  end

  defp setup_deployment_target(ctx) do
    project = %{org_id: ctx.extra_args["organization_id"], id: ctx.extra_args["project_id"]}
    user = %{id: ctx.extra_args["requester_id"]}

    {target, secret} =
      Support.Stubs.Time.travel_back(60, fn ->
        Support.Stubs.Deployments.create(project, user, "target",
          env_vars: [%{name: "VAR", value: "VALUE"}],
          files: [%{path: "FILE", content: "CONTENT"}]
        )
      end)

    {:ok, %{target_id: target.id, target: target, secret_id: secret.id, secret: secret}}
  end

  defp setup_common_args(_ctx) do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user, name: "test_project")
    branch = Support.Stubs.Branch.create(project)
    hook = Support.Stubs.Hook.create(branch)
    workflow = Support.Stubs.Workflow.create(hook, user)

    pipeline =
      Support.Stubs.Pipeline.create(workflow,
        name: "Pipeline",
        commit_message: hook.api_model.commit_message
      )
      |> then(&Support.Stubs.Pipeline.change_state(&1.id, :passed))

    switch = Support.Stubs.Pipeline.add_switch(pipeline)

    {:ok,
     org: org,
     user: user,
     project: project,
     hook: hook,
     workflow: workflow,
     pipeline: pipeline,
     switch: switch}
  end

  defp add_pipeline_promotion(
         ctx,
         target_name,
         deployment_state,
         pipeline_state
       ) do
    target =
      if deployment_state == :STARTED do
        pipeline =
          Support.Stubs.Pipeline.create(ctx.workflow,
            name: "Deploy to #{target_name}",
            promotion_of: ctx.pipeline.id,
            commit_message: ctx.hook.api_model.commit_message
          )
          |> then(&Support.Stubs.Pipeline.change_state(&1.id, pipeline_state))

        Support.Stubs.Deployments.add_deployment(ctx.target, ctx.user, ctx.switch, %{
          pipeline_id: pipeline.id,
          state: deployment_state
        })
      else
        Support.Stubs.Deployments.add_deployment(ctx.target, ctx.user, ctx.switch, %{
          state: deployment_state
        })
      end

    Map.put(ctx, :target, target)
  end

  defp get_history(ctx, params) do
    res = get_history_request(params, ctx)
    {:ok, response} = res
    %{body: body, status_code: status_code, headers: headers} = response

    case Poison.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  def url, do: "localhost:4004"

  def headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp get_history_request(params, ctx) do
    url =
      url() <>
        "/deployment_targets/" <> ctx.target.id <> "/history?" <> Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"]))
  end
end
