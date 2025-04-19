defmodule Router.Stages.ApproveEventTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      org = Support.Stubs.Organization.create(org_id: org_id)
      canvas = Support.Stubs.Canvases.create_canvas(org, name: "canvas-1")
      source = Support.Stubs.Canvases.create_source(org, canvas.id, name: "source-1")
      stage = Support.Stubs.Canvases.create_stage(org, canvas.id, name: "stage-1")

      event =
        Support.Stubs.Canvases.create_stage_event(org, canvas.id, stage.id, source.id,
          name: "stage-1"
        )

      # TODO: this permission should be updated
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.manage")

      {:ok,
       %{
         org_id: org_id,
         org: org,
         user_id: user_id,
         canvas_id: canvas.id,
         stage_id: stage.id,
         event_id: event.id
       }}
    end

    test "approve stage event", ctx do
      {:ok, response} = approve_stage_event(ctx, ctx.stage_id, ctx.event_id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "approve stage event for inexistent stage", ctx do
      {:ok, response} = approve_stage_event(ctx, UUID.uuid4(), ctx.event_id)
      assert 404 == response.status_code
    end

    test "approve stage event for inexistent event", ctx do
      {:ok, response} = approve_stage_event(ctx, ctx.stage_id, UUID.uuid4())
      assert 404 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org = %{id: UUID.uuid4()}
      user_id = UUID.uuid4()
      canvas = Support.Stubs.Canvases.create_canvas(org, name: "canvas-1")
      source = Support.Stubs.Canvases.create_source(org, canvas.id, name: "source-1")
      stage = Support.Stubs.Canvases.create_stage(org, canvas.id, name: "stage-1")

      event =
        Support.Stubs.Canvases.create_stage_event(org, canvas.id, stage.id, source.id,
          name: "stage-1"
        )

      {:ok,
       %{
         org_id: org.id,
         org: org,
         user_id: user_id,
         canvas_id: canvas.id,
         stage_id: stage.id,
         event_id: event.id
       }}
    end

    test "approve stage event", ctx do
      {:ok, response} = approve_stage_event(ctx, ctx.stage_id, ctx.event_id)
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Stages.StageEvent", spec)
  end

  defp approve_stage_event(ctx, id_or_name, event_id) do
    url = url() <> "/canvases/#{ctx.canvas_id}/stages/#{id_or_name}/approve?event_id=#{event_id}"

    HTTPoison.patch(url, "", headers(ctx))
  end
end
