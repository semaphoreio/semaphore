defmodule Router.Deployments.HistoryTest do
  use PublicAPI.Case

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @org_without_feature UUID.uuid4()
  @default_project_id "92be1234-1234-4234-8234-123456789012"
  import Test.PipelinesClient, only: [headers: 1, url: 0]

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()

    project_id = @default_project_id
    user_id = Support.Stubs.User.default_user_id()
    Support.Stubs.Project.create(%{id: @default_org_id}, %{id: user_id}, id: project_id)

    Support.Stubs.Feature.disable_feature(@org_without_feature, "advanced_deployment_targets")

    PermissionPatrol.add_permissions(
      @default_org_id,
      user_id,
      "project.deployment_targets.view",
      project_id
    )

    Support.Stubs.RBAC.seed_data()

    {:ok,
     extra_args: %{
       org_id: @default_org_id,
       project_id: project_id,
       requester_id: Support.Stubs.User.default_user_id(),
       user_id: Support.Stubs.User.default_user_id()
     }}
  end

  describe "GET /deployment_targets/:target_id/history - endpoint returns list of deployments" do
    setup [:setup_deployment_target, :setup_common_args]

    test "request list of deployment targets history and get :ok response", ctx do
      ctx
      |> add_pipeline_promotion("Production", :STARTED, :passed)
      |> add_pipeline_promotion("Production", :STARTED, :failed)
      |> add_pipeline_promotion("Production", :FAILED, :failed)
      |> add_pipeline_promotion("Production", :PENDING, nil)

      params = %{
        "page_token" => "",
        "git_ref_type" => "branch"
      }

      {status_code, _headers, deployments} = get_history(ctx, params)

      assert status_code == 200
      assert length(deployments) == 4

      assert ["STARTED", "STARTED", "FAILED", "PENDING"] =
               Enum.map(deployments, fn dep -> dep["state"] end)
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      params = %{
        "page_token" => "",
        "git_ref_type" => "branch"
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, UUID.uuid4()))
      {_status_code, _headers, message} = get_history(ctx, params)
      # assert status_code == 404
      assert message["message"] =~ "Not Found"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      org_id = UUID.uuid4()
      Support.Stubs.Feature.disable_feature(org_id, "deployment_targets")
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, org_id))

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, UUID.uuid4()))
      {status_code, _headers, message} = get_history(ctx, %{})
      assert status_code == 404

      assert message["message"] ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end
  end

  defp setup_deployment_target(ctx) do
    project = %{org_id: ctx.extra_args.org_id, id: ctx.extra_args.project_id}
    user = %{id: ctx.extra_args.requester_id}

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

    project =
      Support.Stubs.Project.create(org, user, name: "test_project", id: @default_project_id)

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

    case Jason.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  defp get_history_request(params, ctx) do
    url =
      url() <>
        "/projects/" <>
        ctx.extra_args.project_id <>
        "/deployment_targets/" <> ctx.target.id <> "/history?" <> Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx.extra_args))
  end
end
