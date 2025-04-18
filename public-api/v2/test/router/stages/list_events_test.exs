defmodule Router.Stages.ListEventsTest do
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
      Support.Stubs.Canvases.create_stage_event(org, canvas.id, stage.id, source.id, name: "stage-1")

      # TODO: this permission should be updated
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok,
       %{
        org_id: org_id,
        org: org,
        user_id: user_id,
        canvas_id: canvas.id,
        stage_id: stage.id,
        stage_name: stage.name,
        source_id: source.id,
        source_name: source.name
       }}
    end

    test "list stage events", ctx do
      {:ok, response} = list_stage_events(ctx, ctx.canvas_id, ctx.stage_id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "list stage events for inexistent canvas", ctx do
      {:ok, response} = list_stage_events(ctx, UUID.uuid4(), ctx.stage_id)
      assert 200 == response.status_code
    end

    test "list stage events for inexistent stage", ctx do
      {:ok, response} = list_stage_events(ctx, UUID.uuid4(), UUID.uuid4())
      assert 200 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org = %{id: UUID.uuid4()}
      user_id = UUID.uuid4()
      canvas = Support.Stubs.Canvases.create_canvas(org, name: "canvas-1")
      source = Support.Stubs.Canvases.create_source(org, canvas.id, name: "source-1")
      stage = Support.Stubs.Canvases.create_stage(org, canvas.id, name: "stage-1")
      Support.Stubs.Canvases.create_stage_event(org, canvas.id, stage.id, source.id, name: "stage-1")

      {:ok,
       %{
        org_id: org.id,
        org: org,
        user_id: user_id,
        canvas_id: canvas.id,
        stage_id: stage.id,
        stage_name: stage.name,
        source_id: source.id,
        source_name: source.name
       }}
    end

    test "list stage events", ctx do
      {:ok, response} = list_stage_events(ctx, ctx.canvas_id, ctx.stage_id)
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Stages.ListEventsResponse", spec)
  end

  defp list_stage_events(ctx, canvas_id_or_name, id_or_name) do
    url = url() <> "/canvases/#{canvas_id_or_name}/stages/#{id_or_name}/events"

    HTTPoison.get(url, headers(ctx))
  end
end
