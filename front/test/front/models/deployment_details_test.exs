# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Models.DeploymentDetailsTest do
  use ExUnit.Case, async: false
  @moduletag capture_log: true
  @moduletag :deployments

  alias Front.Models.DeploymentDetails, as: Details
  alias Front.Models.DeploymentDetails.HistoryPage
  alias Front.Models.Deployments

  alias Front.Models.Pipeline
  alias Front.Models.RepoProxy
  alias Support.Stubs

  setup_all _ctx do
    on_exit(fn ->
      Support.Stubs.init()
      Support.Stubs.build_shared_factories()
    end)
  end

  setup ctx do
    Support.Stubs.init()
    setup_common_args(ctx)
  end

  describe "HistoryPage" do
    setup ctx do
      create_deployment_target(ctx, "production", cordoned: true)
      |> add_deployment(:FAILED)
      |> add_deployment(:STARTED, :passed)
      |> add_deployment(:PENDING)
    end

    test "construct/1 constructs page struct", ctx do
      assert {:ok, deployments} = Deployments.fetch_history(ctx.deployment_target.id)
      assert page = %HistoryPage{deployments: deployments} = HistoryPage.construct(deployments)
      refute page.cursor_before
      refute page.cursor_after

      assert Enum.all?(deployments, &match?(%Details.Deployment{}, &1))
      assert Enum.all?(deployments, &UUID.info!(&1.id))
      assert Enum.all?(deployments, &UUID.info!(&1.pipeline_id))
      assert Enum.all?(deployments, &UUID.info!(&1.triggered_by))
      assert Enum.all?(deployments, &is_integer(&1.triggered_at))

      assert Enum.all?(deployments, &UUID.info!(&1.switch_id))
      assert Enum.all?(deployments, &String.starts_with?(&1.target_name, "Deploy"))

      refute Enum.any?(deployments, & &1.pipeline)
      refute Enum.any?(deployments, & &1.hook)
      refute Enum.any?(deployments, & &1.author_name)
      refute Enum.any?(deployments, & &1.author_avatar_url)
    end

    test "load/1 preloads pipeline info", ctx do
      assert {:ok, deployments} = Deployments.fetch_history(ctx.deployment_target.id)
      assert page = %HistoryPage{} = HistoryPage.construct(deployments)
      assert page = %HistoryPage{} = HistoryPage.load(page)

      assert Enum.count(page.deployments) == 3
      assert Enum.all?(page.deployments, &match?(%Details.Deployment{}, &1))
      assert Enum.all?(page.deployments, &match?(%Pipeline{}, &1.pipeline))
    end

    test "load/1 preloads hook info", ctx do
      assert {:ok, deployments} = Deployments.fetch_history(ctx.deployment_target.id)
      assert page = %HistoryPage{} = HistoryPage.construct(deployments)
      assert page = %HistoryPage{} = HistoryPage.load(page)

      assert Enum.count(page.deployments) == 3
      assert Enum.all?(page.deployments, &match?(%Details.Deployment{}, &1))
      assert Enum.all?(page.deployments, &match?(%RepoProxy{}, &1.hook))
    end

    test "load/1 preloads triggerer info", ctx do
      assert {:ok, deployments} = Deployments.fetch_history(ctx.deployment_target.id)
      assert page = %HistoryPage{} = HistoryPage.construct(deployments)
      assert page = %HistoryPage{} = HistoryPage.load(page)

      assert Enum.count(page.deployments) == 3
      assert Enum.all?(page.deployments, &match?(%Details.Deployment{}, &1))
      assert Enum.all?(page.deployments, &(&1.author_name == "Jane"))
    end
  end

  describe "construct/1" do
    test "constructs basic info from list", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      create_deployment_target(ctx, "staging", cordoned: true)
      |> put_last_deployment(:PENDING)

      create_deployment_target(ctx, "development")
      |> put_last_deployment(:FAILED)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)
      assert target_details = Details.construct(targets)

      for details <- target_details do
        assert details.name in ["production", "staging", "development"]
        assert String.ends_with?(details.description, "deployment target")
        assert String.starts_with?(details.url, "https://")
        assert String.ends_with?(details.url, "example.com")
        assert :USABLE == details.state

        assert %Details.Deployment{} = details.last_deployment
        assert UUID.info!(details.last_deployment.id)
        assert UUID.info!(details.last_deployment.pipeline_id)
        assert UUID.info!(details.last_deployment.triggered_by)
        assert is_integer(details.last_deployment.triggered_at)

        assert UUID.info!(details.last_deployment.switch_id)
        assert String.starts_with?(details.last_deployment.target_name, "Deploy")

        refute details.last_deployment.pipeline
        refute details.last_deployment.hook
        refute details.last_deployment.author_name
        refute details.last_deployment.author_avatar_url

        if details.name == "staging",
          do: assert(details.cordoned?)
      end
    end

    test "constructs basic info from single element", ctx do
      ctx =
        create_deployment_target(ctx, "production", cordoned: true)
        |> add_deployment(:FAILED)
        |> add_deployment(:STARTED, :passed)
        |> add_deployment(:PENDING)

      assert {:ok, target} = Deployments.fetch_target(ctx.deployment_target.id)
      assert details = Details.construct(target)

      assert details.name == "production"
      assert String.ends_with?(details.description, "deployment target")
      assert String.starts_with?(details.url, "https://")
      assert String.ends_with?(details.url, "example.com")
      assert :USABLE == details.state
      assert details.cordoned?
    end
  end

  describe "load/2" do
    setup ctx do
      create_deployment_target(ctx, "production", cordoned: true)
      |> add_deployment(:FAILED)
      |> add_deployment(:STARTED, :passed)
      |> add_deployment(:PENDING)
    end

    test "preloads pipeline info", ctx do
      assert {:ok, target} = Deployments.fetch_target(ctx.deployment_target.id)
      assert {:ok, deployments} = Deployments.fetch_history(ctx.deployment_target.id)
      assert history_page = %HistoryPage{} = HistoryPage.construct(deployments)

      assert details = Details.load(target, history_page)

      assert Enum.count(details.history_page.deployments) == 3
      assert Enum.all?(details.history_page.deployments, &match?(%Details.Deployment{}, &1))
      assert Enum.all?(details.history_page.deployments, &match?(%Pipeline{}, &1.pipeline))
    end

    test "preloads hook info", ctx do
      assert {:ok, target} = Deployments.fetch_target(ctx.deployment_target.id)
      assert {:ok, deployments} = Deployments.fetch_history(ctx.deployment_target.id)
      assert history_page = %HistoryPage{} = HistoryPage.construct(deployments)

      assert details = Details.load(target, history_page)

      assert Enum.count(details.history_page.deployments) == 3
      assert Enum.all?(details.history_page.deployments, &match?(%Details.Deployment{}, &1))
      assert Enum.all?(details.history_page.deployments, &match?(%Pipeline{}, &1.pipeline))
      assert Enum.all?(details.history_page.deployments, &match?(%RepoProxy{}, &1.hook))
    end

    test "preloads triggerer info", ctx do
      assert {:ok, target} = Deployments.fetch_target(ctx.deployment_target.id)
      assert {:ok, deployments} = Deployments.fetch_history(ctx.deployment_target.id)
      assert history_page = %HistoryPage{} = HistoryPage.construct(deployments)

      assert details = Details.load(target, history_page)

      assert Enum.count(details.history_page.deployments) == 3
      assert Enum.all?(details.history_page.deployments, &match?(%Details.Deployment{}, &1))
      assert Enum.all?(details.history_page.deployments, &(&1.author_name == "Jane"))
    end
  end

  describe "preload_pipelines/1" do
    test "when target has last deployment then preload pipeline info", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)
      assert [target_details] = targets |> Details.construct() |> Details.preload_pipelines()

      assert %Details.Deployment{} = target_details.last_deployment
      assert %Pipeline{} = target_details.last_deployment.pipeline
    end

    test "when target has pending last deployment then preload pipeline info", ctx do
      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:PENDING)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)
      assert [target_details] = targets |> Details.construct() |> Details.preload_pipelines()

      assert %Details.Deployment{} = target_details.last_deployment
      assert %Pipeline{} = target_details.last_deployment.pipeline
    end

    test "when target has failed last deployment then preload pipeline info", ctx do
      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:FAILED)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)
      assert [target_details] = targets |> Details.construct() |> Details.preload_pipelines()

      assert %Details.Deployment{} = target_details.last_deployment
      assert %Pipeline{} = target_details.last_deployment.pipeline
    end

    test "works with many targets", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:PENDING)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)
      assert target_details = targets |> Details.construct() |> Details.preload_pipelines()

      assert production = Enum.find(target_details, &(&1.name == "production"))
      assert %Details.Deployment{} = production.last_deployment
      assert %Pipeline{} = production.last_deployment.pipeline

      assert staging = Enum.find(target_details, &(&1.name == "staging"))
      assert %Details.Deployment{} = staging.last_deployment
      assert %Pipeline{} = staging.last_deployment.pipeline
    end
  end

  describe "preload_hooks/1" do
    test "when target has last deployment then preload hook info", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert [target_details] =
               targets
               |> Details.construct()
               |> Details.preload_pipelines()
               |> Details.preload_hooks()

      assert %Details.Deployment{} = target_details.last_deployment
      assert %RepoProxy{} = target_details.last_deployment.hook
    end

    test "when target has pending last deployment then preload hook info", ctx do
      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:PENDING)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert [target_details] =
               targets
               |> Details.construct()
               |> Details.preload_pipelines()
               |> Details.preload_hooks()

      assert %Details.Deployment{} = target_details.last_deployment
      assert %RepoProxy{} = target_details.last_deployment.hook
    end

    test "when target has failed last deployment then preload hook info", ctx do
      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:FAILED)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert [target_details] =
               targets
               |> Details.construct()
               |> Details.preload_pipelines()
               |> Details.preload_hooks()

      assert %Details.Deployment{} = target_details.last_deployment
      assert %RepoProxy{} = target_details.last_deployment.hook
    end

    test "when pipeline info is missing then don't preload hooks", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:PENDING)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert target_details =
               targets
               |> Details.construct()
               |> Details.preload_hooks()

      assert Enum.all?(
               target_details,
               &(is_nil(&1.last_deployment) or
                   is_nil(&1.last_deployment.hook))
             )
    end

    test "works with many targets", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:PENDING)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert target_details =
               targets
               |> Details.construct()
               |> Details.preload_pipelines()
               |> Details.preload_hooks()

      assert production = Enum.find(target_details, &(&1.name == "production"))
      assert %Details.Deployment{} = production.last_deployment
      assert %RepoProxy{} = production.last_deployment.hook

      assert staging = Enum.find(target_details, &(&1.name == "staging"))
      assert %Details.Deployment{} = staging.last_deployment
      assert %RepoProxy{} = staging.last_deployment.hook
    end
  end

  describe "preload_users/1" do
    test "when target has last deployment then preloads triggerer", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert [target_details] =
               targets
               |> Details.construct()
               |> Details.preload_users()

      assert %Details.Deployment{} = target_details.last_deployment
      assert "Jane" = target_details.last_deployment.author_name
    end

    test "when target has last deployment from auto-promotion then preloads triggerer", ctx do
      %{deployment_target: target, promotion_pipeline: pipeline} =
        create_deployment_target(ctx, "production")
        |> put_last_deployment(:STARTED, :passed)

      Stubs.Deployments.put_last_deployment(target, %{id: "Pipeline Done request"}, ctx.switch, %{
        pipeline_id: pipeline.id,
        state: :STARTED
      })

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert [target_details] =
               targets
               |> Details.construct()
               |> Details.preload_users()

      assert %Details.Deployment{} = target_details.last_deployment
      assert "Auto-promotion" = target_details.last_deployment.author_name

      assert String.ends_with?(
               target_details.last_deployment.author_avatar_url,
               "profile-bot.svg"
             )
    end

    test "when target has pending last deployment then preload hook info", ctx do
      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:PENDING)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert [target_details] =
               targets
               |> Details.construct()
               |> Details.preload_users()

      assert %Details.Deployment{} = target_details.last_deployment
      assert "Jane" = target_details.last_deployment.author_name
    end

    test "when target has failed last deployment then preload hook info", ctx do
      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:FAILED)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)

      assert [target_details] =
               targets
               |> Details.construct()
               |> Details.preload_users()

      assert %Details.Deployment{} = target_details.last_deployment
      assert "Jane" = target_details.last_deployment.author_name
    end

    test "works with many targets", ctx do
      create_deployment_target(ctx, "production")
      |> put_last_deployment(:STARTED, :passed)

      create_deployment_target(ctx, "staging")
      |> put_last_deployment(:PENDING)

      assert {:ok, targets} = Deployments.fetch_targets(ctx.project.id)
      assert target_details = targets |> Details.construct() |> Details.preload_users()

      assert production = Enum.find(target_details, &(&1.name == "production"))
      assert %Details.Deployment{} = production.last_deployment
      assert "Jane" = production.last_deployment.author_name

      assert staging = Enum.find(target_details, &(&1.name == "staging"))
      assert %Details.Deployment{} = staging.last_deployment
      assert "Jane" = staging.last_deployment.author_name
    end
  end

  defp setup_common_args(_ctx) do
    org = Stubs.Organization.create_default()
    user = Stubs.User.create_default()
    project = Stubs.Project.create(org, user, name: "test_project")

    branch = Stubs.Branch.create(project)
    hook = Stubs.Hook.create(branch)
    workflow = Stubs.Workflow.create(hook, user)

    pipeline =
      Stubs.Pipeline.create(workflow,
        name: "Pipeline",
        commit_message: hook.api_model.commit_message
      )
      |> then(&Stubs.Pipeline.change_state(&1.id, :passed))

    switch = Stubs.Pipeline.add_switch(pipeline)

    {:ok,
     org: org,
     user: user,
     project: project,
     hook: hook,
     workflow: workflow,
     pipeline: pipeline,
     switch: switch}
  end

  defp create_deployment_target(ctx, target_name, params \\ []) do
    params =
      Map.merge(
        %{
          description: "#{target_name} deployment target",
          url: "https://#{target_name}.example.com"
        },
        Map.new(params)
      )

    {deployment_target, _} =
      Support.Stubs.Deployments.create(ctx.project, ctx.user, target_name, params)

    Map.put(ctx, :deployment_target, deployment_target)
  end

  defp put_last_deployment(ctx, deployment_state, pipeline_state \\ nil) do
    promotion_pipeline =
      if deployment_state == :STARTED do
        Stubs.Pipeline.create(ctx.workflow,
          name: "Deploy to #{ctx.deployment_target.name}",
          promotion_of: ctx.pipeline.id,
          commit_message: ctx.hook.api_model.commit_message
        )
        |> then(&Stubs.Pipeline.change_state(&1.id, pipeline_state))
      end

    deployment_target =
      Stubs.Deployments.put_last_deployment(ctx.deployment_target, ctx.user, ctx.switch, %{
        pipeline_id: promotion_pipeline && promotion_pipeline.id,
        state: deployment_state
      })

    Map.merge(ctx, %{deployment_target: deployment_target, promotion_pipeline: promotion_pipeline})
  end

  defp add_deployment(ctx, deployment_state, pipeline_state \\ nil) do
    promotion_pipeline =
      if deployment_state == :STARTED do
        Stubs.Pipeline.create(ctx.workflow,
          name: "Deploy to #{ctx.deployment_target.name}",
          promotion_of: ctx.pipeline.id,
          commit_message: ctx.hook.api_model.commit_message
        )
        |> then(&Stubs.Pipeline.change_state(&1.id, pipeline_state))
      end

    deployment_target =
      Stubs.Deployments.add_deployment(ctx.deployment_target, ctx.user, ctx.switch, %{
        pipeline_id: promotion_pipeline && promotion_pipeline.id,
        state: deployment_state
      })

    Map.merge(ctx, %{deployment_target: deployment_target, promotion_pipeline: promotion_pipeline})
  end
end
