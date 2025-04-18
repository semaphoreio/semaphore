defmodule Router.EventSources.DescribeTest do
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

      # TODO: this permission should be updated
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok,
       %{
        org_id: org_id,
        org: org,
        user_id: user_id,
        canvas_id: canvas.id,
        source_id: source.id,
        source_name: source.name
       }}
    end

    test "describe an event source using id", ctx do
      {:ok, response} = get_source(ctx, ctx.canvas_id, ctx.source_id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe an event source using name", ctx do
      {:ok, response} = get_source(ctx, ctx.canvas_id, ctx.source_name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a non-existent source", ctx do
      {:ok, response} = get_source(ctx, ctx.canvas_id, "non-existent")
      assert 404 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      canvas = Support.Stubs.Canvases.create_canvas(%{id: org_id}, name: "canvas-1")
      source = Support.Stubs.Canvases.create_source(%{id: org_id}, canvas.id, name: "source-1")

      {:ok,
       %{
        org_id: org_id,
        org: %{id: org_id},
        user_id: user_id,
        canvas_id: canvas.id,
        source_id: source.id,
        source_name: source.name
       }}
    end

    test "describe a source by id", ctx do
      {:ok, response} = get_source(ctx, ctx.canvas_id, ctx.source_id)
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "EventSource", spec)
  end

  defp get_source(ctx, canvas_id_or_name, id_or_name) do
    url = url() <> "/canvases/#{canvas_id_or_name}/sources/#{id_or_name}"

    HTTPoison.get(url, headers(ctx))
  end
end
