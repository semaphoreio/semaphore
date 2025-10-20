defmodule Front.Browser.WorkflowPage do
  use FrontWeb.WallabyCase

  import Mock

  @edit_link Query.link("Edit Workflow")
  @waiting_for_quota_bagde Query.text("Waiting for quota")

  setup data do
    stubs = Support.Browser.WorkflowPage.create_workflow()

    Support.Stubs.PermissionPatrol.allow_everything()

    params = Map.merge(data, stubs)

    {:ok, params}
  end

  describe "header" do
    test "the users can see information about the commit", params do
      page = open(params)

      assert_text(page, params.hook.api_model.commit_message)
      assert_text(page, String.slice(params.hook.api_model.head_commit_sha, 0..6))
    end
  end

  describe "diagram" do
    test "the users can see the pipeline", params do
      page = open(params)

      assert_text(page, "Build & Test")
      assert_text(page, "Block 1")
      assert_text(page, "Block 2")
      assert_text(page, "Block 3")
    end

    test "the users can see promotions", params do
      page = open(params)

      assert_text(page, "Production")
      assert_text(page, "Staging")
    end

    test "promotions with unicode characters (emoji) are displayed correctly", params do
      switch = params.switch
      Support.Stubs.Switch.add_target(switch, name: "Deploy 🚀 Production")

      page = open(params)

      assert_text(page, "Deploy 🚀 Production")
    end

    test "promotions with accented characters are displayed correctly", params do
      switch = params.switch
      Support.Stubs.Switch.add_target(switch, name: "Déploiement Français")

      page = open(params)

      assert_text(page, "Déploiement Français")
    end

    test "promotions with CJK characters are displayed correctly", params do
      switch = params.switch
      Support.Stubs.Switch.add_target(switch, name: "部署到生产环境")

      page = open(params)

      assert_text(page, "部署到生产环境")
    end

    test "promotions with single quotes are displayed and clickable", params do
      switch = params.switch
      Support.Stubs.Switch.add_target(switch, name: "Publish 'my-package' to Production")

      page = open(params)

      assert_text(page, "Publish 'my-package' to Production")
      assert find(page, Query.button("Publish 'my-package' to Production"))
    end

    test "promotions with mixed unicode and special characters work correctly", params do
      switch = params.switch
      Support.Stubs.Switch.add_target(switch, name: "Deploy 'app' 🎉 to Staging")

      page = open(params)

      assert_text(page, "Deploy 'app' 🎉 to Staging")
      assert find(page, Query.button("Deploy 'app' 🎉 to Staging"))
    end

    test "If project is public, show blocks, but promotions should be disabled", params do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      with_mocks([
        {FrontWeb.Plugs.PublicPageAccess, [:passthrough],
         [call: fn conn, _ -> Plug.Conn.assign(conn, :authorization, :guest) end]}
      ]) do
        page = open(params)

        assert_text(page, "Build & Test")
        assert_text(page, "Block 1")
        assert_text(page, "Block 2")
        assert_text(page, "Block 3")

        assert find(page, Query.button("Production")) |> Element.attr("disabled") == "true"
        assert find(page, Query.button("Staging")) |> Element.attr("disabled") == "true"
      end
    end
  end

  describe "editing a workflow" do
    test "edit button is visible when user has write github access", params do
      open(params) |> assert_has(@edit_link)
    end

    test "click on 'edit' opens the Visual Builder", params do
      open(params) |> click(@edit_link) |> assert_text("Visual Builder")
    end
  end

  describe "waiting time" do
    setup params do
      Support.Stubs.Pipeline.change_state(params.pipeline.id, :running)

      {:ok, params}
    end

    test "when the waiting is > 20 secs => display link to Activity Monitor", params do
      Support.Stubs.Time.travel_back(:timer.minutes(15), fn ->
        params.blocks |> Enum.each(fn block -> Support.Stubs.Task.create(block) end)
      end)

      params.session |> take_screenshot()

      open(params) |> assert_has(@waiting_for_quota_bagde)
    end

    test "when the waiting is < 20 secs => don't display Activity link", params do
      open(params) |> refute_has(@waiting_for_quota_bagde)
    end
  end

  defp open(params) do
    path = "/workflows/#{params.workflow.id}?pipeline_id=#{params.pipeline.id}"

    params.session |> visit(path)
  end
end
