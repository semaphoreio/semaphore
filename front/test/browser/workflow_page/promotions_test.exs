defmodule Front.Browser.WorkflowPage.PromotionsTest do
  use FrontWeb.WallabyCase

  setup data do
    stubs = Support.Browser.WorkflowPage.create_workflow()

    Support.Stubs.PermissionPatrol.allow_everything()

    context = Map.merge(data, stubs)

    {:ok, context}
  end

  test "when target has parameters form is prefilled and displayed", ctx do
    page = open(ctx)

    assert_text(page, "Production")
    click(page, Query.button("Production"))

    assert has_text?(page, "SERVER_IP")
    assert has_value?(page, Query.text_field("SERVER_IP"), "1.2.3.4")
    assert has_text?(page, "Where to deploy?")

    assert has_text?(page, "STRATEGY")
    assert has_value?(page, Query.option("fast (default)"), "fast")
    assert has_value?(page, Query.option("slow"), "slow")
    assert has_text?(page, "Which deployment strategy should be used?")
  end

  @tag :skip
  test "promoting target with empty required parameter throws error", ctx do
    page = open(ctx)

    assert_text(page, "QA")
    click(page, Query.button("QA"))

    assert has_text?(page, "REVIEWER")
    assert has_value?(page, Query.text_field("REVIEWER"), "")
    assert has_text?(page, "Who should review this?")

    click(page, Query.button("Start promotion"))
    assert_has(page, Query.css(".form-control-error"))
  end

  test "when target has blocking deployment target and deployment targets are disabled", ctx do
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

  test "when target has allowing deployment target and deployment targets are disabled", ctx do
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

  test "when target with no parameters is promoted, show yes/cancel options", ctx do
    page = open(ctx)

    assert_text(page, "Staging")
    click(page, Query.button("Staging"))

    assert has_text?(page, "Start promotion")
    assert has_text?(page, "Nevermind")
  end

  describe "when deployment targets are enabled" do
    setup ctx do
      Support.Stubs.Feature.enable_feature(ctx.org.id, :deployment_targets)
      on_exit(fn -> Support.Stubs.Feature.disable_feature(ctx.org.id, :deployment_targets) end)
    end

    test "when target has deployment target that blocks promotion", ctx do
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

    test "when target has deployment target that allows promotion", ctx do
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
