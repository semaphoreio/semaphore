defmodule Router.Canvases.DescribeTest do
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

      # TODO: this permission should be updated
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok,
       %{
         org_id: org_id,
         org: org,
         user_id: user_id,
         canvas_id: canvas.id,
         canvas_name: canvas.name
       }}
    end

    test "describe a canvas by id", ctx do
      {:ok, response} = get_canvas(ctx, ctx.canvas_id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a canvas by name", ctx do
      {:ok, response} = get_canvas(ctx, ctx.canvas_name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a non-existent canvas", ctx do
      {:ok, response} = get_canvas(ctx, "non-existent")
      assert 404 == response.status_code
    end

    test "describe a canvas that is not owned by the requester org", ctx do
      wrong_org_id = UUID.uuid4()
      canvas = Support.Stubs.Canvases.create_canvas(%{id: wrong_org_id})

      {:ok, response} = get_canvas(ctx, canvas.id)
      assert 404 == response.status_code
      assert %{"message" => "Not found"} = Jason.decode!(response.body)
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      canvas = Support.Stubs.Canvases.create_canvas(%{id: org_id}, name: "canvas-2")

      {:ok,
       %{
         org_id: org_id,
         user_id: user_id,
         canvas_id: canvas.id,
         canvas_name: canvas.name
       }}
    end

    test "describe a canvas by id", ctx do
      {:ok, response} = get_canvas(ctx, ctx.canvas_id)
      assert 404 == response.status_code
    end

    test "describe a canvas by name", ctx do
      {:ok, response} = get_canvas(ctx, ctx.canvas_name)
      assert 404 == response.status_code
    end

    test "describe a non-existent canvas", ctx do
      {:ok, response} = get_canvas(ctx, "non-existent")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Canvas", spec)
  end

  defp get_canvas(ctx, id_or_name) do
    url = url() <> "/canvases/#{id_or_name}"

    HTTPoison.get(url, headers(ctx))
  end
end
