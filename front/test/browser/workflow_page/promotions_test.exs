defmodule Front.Browser.WorkflowPage.PromotionsTest do
  use FrontWeb.WallabyCase

  setup data do
    stubs = Support.Browser.WorkflowPage.create_workflow()

    Support.Stubs.PermissionPatrol.allow_everything()

    context = Map.merge(data, stubs)

    {:ok, context}
  end

  browser_test "when target has parameters form is prefilled and displayed", ctx do
    page = open(ctx)

    assert_text(page, "Production")
    click(page, Query.button("Production"))

    assert has_text?(page, "SERVER_IP")
    assert has_value?(page, Query.text_field("SERVER_IP"), "1.2.3.4")
    assert has_text?(page, "Where to deploy?")

    assert has_text?(page, "STRATEGY")
    assert has_text?(page, Query.data("value", "fast"), "fast (default)")
    assert has_text?(page, "Which deployment strategy should be used?")
  end

  browser_test "promoting target with empty required parameter throws error", ctx do
    page = open(ctx)

    assert_text(page, "QA")
    click(page, Query.button("QA"))

    assert has_text?(page, "REVIEWER")
    assert has_value?(page, Query.text_field("REVIEWER"), "")
    assert has_text?(page, "Who should review this?")

    click(page, Query.button("Start promotion"))
    assert_has(page, Query.css(".form-control-error"))
  end

  browser_test "when target has blocking deployment target and deployment targets are disabled",
               ctx do
    configure_dt_promotion(ctx, "Production", %{
      allowed: false,
      reason: :BANNED_SUBJECT,
      message: "You cannot deploy"
    })

    page = open(ctx)

    refute_has(page, Query.text("Production"))
    refute_has(page, Query.css(".dt-icon", text: "lock"))
    refute_has(page, Query.button("Deploy to Production", maximum: 1))
    refute_has(page, Query.text("You cannot deploy"))
  end

  browser_test "when target has allowing deployment target and deployment targets are disabled",
               ctx do
    configure_dt_promotion(ctx, "Production", %{
      allowed: true,
      reason: :NO_REASON,
      message: "You can deploy"
    })

    page = open(ctx)

    refute_has(page, Query.text("Production"))
    refute_has(page, Query.css(".dt-icon", text: "lock"))
    refute_has(page, Query.button("Deploy to Production"))
    refute_has(page, Query.text("You cannot deploy"))
  end

  browser_test "when target with no parameters is promoted, show yes/cancel options", ctx do
    page = open(ctx)

    assert_text(page, "Staging")
    click(page, Query.button("Staging"))

    assert has_text?(page, "Start promotion")
    assert has_text?(page, "Nevermind")
  end

  browser_test "promotion targets with single quotes render and open correctly", ctx do
    quoted_name = "Publish 'my-package' to Production"
    Support.Stubs.Switch.add_target(ctx.switch, name: quoted_name)

    page = open(ctx)

    assert_has(page, Query.button(quoted_name))
    click(page, Query.button(quoted_name))

    assert_has(
      page,
      Query.css("[promote-confirmation][data-promotion-target=\"#{quoted_name}\"]")
    )

    assert_has(page, Query.text("Promote to #{quoted_name}?"))
  end

  browser_test "promotion targets with double quotes render and open correctly", ctx do
    quoted_name = ~s(Deploy "production" build)
    Support.Stubs.Switch.add_target(ctx.switch, name: quoted_name)

    page = open(ctx)

    # Use CSS selector with data attribute since XPath queries don't handle embedded quotes
    click(page, Query.css("[promote-button][data-promotion-target='#{quoted_name}']"))

    # Verify confirmation dialog appeared
    assert_has(page, Query.css("[promote-confirmation][data-promotion-target='#{quoted_name}']"))
  end

  browser_test "promotion targets with backslashes render and open correctly", ctx do
    name_with_backslash = "Deploy\\Staging\\App"
    Support.Stubs.Switch.add_target(ctx.switch, name: name_with_backslash)

    page = open(ctx)

    assert_has(page, Query.button(name_with_backslash))
    click(page, Query.button(name_with_backslash))
    assert_has(page, Query.text("Promote to #{name_with_backslash}?"))
  end

  browser_test "promotion targets with brackets and special characters work correctly", ctx do
    special_name = "Deploy[test]:value.config"
    Support.Stubs.Switch.add_target(ctx.switch, name: special_name)

    page = open(ctx)

    assert_has(page, Query.button(special_name))
    click(page, Query.button(special_name))
    assert_has(page, Query.text("Promote to #{special_name}?"))
  end

  browser_test "promotion targets with emoji render and open correctly", ctx do
    emoji_name = "Deploy 🚀 to Production"
    Support.Stubs.Switch.add_target(ctx.switch, name: emoji_name)

    page = open(ctx)

    assert_has(page, Query.button(emoji_name))
    click(page, Query.button(emoji_name))
    assert_has(page, Query.text("Promote to #{emoji_name}?"))
  end

  browser_test "promotion targets with accented characters render and open correctly", ctx do
    accented_name = "Déploiement Français"
    Support.Stubs.Switch.add_target(ctx.switch, name: accented_name)

    page = open(ctx)

    assert_has(page, Query.button(accented_name))
    click(page, Query.button(accented_name))
    assert_has(page, Query.text("Promote to #{accented_name}?"))
  end

  browser_test "promotion targets with CJK characters render and open correctly", ctx do
    cjk_name = "部署到生产环境"
    Support.Stubs.Switch.add_target(ctx.switch, name: cjk_name)

    page = open(ctx)

    assert_has(page, Query.button(cjk_name))
    click(page, Query.button(cjk_name))
    assert_has(page, Query.text("Promote to #{cjk_name}?"))
  end

  browser_test "promotion targets with mixed special characters and unicode work correctly",
               ctx do
    mixed_name = "Deploy 'app' 🎉 to Production"
    Support.Stubs.Switch.add_target(ctx.switch, name: mixed_name)

    page = open(ctx)

    assert_has(page, Query.button(mixed_name))
    click(page, Query.button(mixed_name))
    assert_has(page, Query.text("Promote to #{mixed_name}?"))
  end

  browser_test "promotion targets with complex bracket and quote combinations work correctly",
               ctx do
    complex_name = "test[data] 'value' config"
    Support.Stubs.Switch.add_target(ctx.switch, name: complex_name)

    page = open(ctx)

    assert_has(page, Query.button(complex_name))
    click(page, Query.button(complex_name))
    assert_has(page, Query.text("Promote to #{complex_name}?"))
  end

  describe "when deployment targets are enabled" do
    setup ctx do
      Support.Stubs.Feature.enable_feature(ctx.org.id, :deployment_targets)
      on_exit(fn -> Support.Stubs.Feature.disable_feature(ctx.org.id, :deployment_targets) end)
    end

    browser_test "when target has deployment target that blocks promotion", ctx do
      configure_dt_promotion(ctx, "Production", %{
        allowed: false,
        reason: :BANNED_SUBJECT,
        message: "You cannot deploy to %{deployment_target}"
      })

      page = open(ctx)
      assert_text(page, "Deploy to Production")

      assert_has(page, Query.css(".dt-icon", text: "lock"))
      assert_has(page, Query.button("Deploy to Production", count: 1))
      assert_has(page, Query.css("button[disabled]", count: 1))
      assert_has(page, Query.text("You cannot deploy"))
      assert_has(page, Query.link("ProductionDT"))
    end

    browser_test "when target has deployment target that allows promotion", ctx do
      configure_dt_promotion(ctx, "Production", %{
        allowed: true,
        reason: :NO_REASON,
        message: "You can deploy to %{deployment_target}"
      })

      page = open(ctx)
      assert_text(page, "Deploy to Production")

      assert_has(page, Query.css(".dt-icon", text: "lock"))
      assert_has(page, Query.button("Deploy to Production", count: 1))
      refute_has(page, Query.css("button[disabled]"))
      assert_has(page, Query.text("You can deploy"))
      assert_has(page, Query.link("ProductionDT"))
    end
  end

  defp open(params) do
    path = "/workflows/#{params.workflow.id}?pipeline_id=#{params.pipeline.id}"

    params.session |> visit(path)
  end

  defp configure_dt_promotion(ctx, name, access) do
    Support.Stubs.Switch.remove_all_targets(ctx.switch)

    Support.Stubs.Switch.add_target(ctx.switch,
      name: "Deploy to #{name}",
      dt_description: %{
        target_id: UUID.uuid4(),
        target_name: "#{name}DT",
        access: access
      }
    )
  end
end
