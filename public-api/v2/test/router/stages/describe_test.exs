defmodule Router.Stages.DescribeTest do
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

    test "describe a stage using id", ctx do
      {:ok, response} = get_stage(ctx, ctx.canvas_id, ctx.stage_id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a stage using name", ctx do
      {:ok, response} = get_stage(ctx, ctx.canvas_id, ctx.stage_name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a non-existent stage", ctx do
      {:ok, response} = get_stage(ctx, ctx.canvas_id, "non-existent")
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

    test "describe a stage by id", ctx do
      {:ok, response} = get_stage(ctx, ctx.canvas_id, ctx.stage_id)
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Stage", spec)
  end

  defp get_stage(ctx, canvas_id_or_name, id_or_name) do
    url = url() <> "/canvases/#{canvas_id_or_name}/stages/#{id_or_name}"

    HTTPoison.get(url, headers(ctx))
  end
end
