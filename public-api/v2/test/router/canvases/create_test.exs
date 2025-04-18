defmodule Router.Canvases.CreateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      # TODO: update these permissions
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.manage")

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "create a canvas", ctx do
      canvas =
        construct_canvas(%{
          organization_id: ctx.org_id,
          name: "canvas-1"
        })

      {:ok, response} = create_canvas(ctx, canvas)
      created_canvas = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_canvas)
      assert canvas.metadata.name == created_canvas["metadata"]["name"]
    end

    test "random version => fail", ctx do
      canvas = construct_canvas() |> Map.put(:apiVersion, "v3")
      {:ok, response} = create_canvas(ctx, canvas)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      canvas = construct_canvas() |> Map.put(:kind, "Foo")
      {:ok, response} = create_canvas(ctx, canvas)

      assert 422 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      # TODO: update these permissions
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "create a canvas", ctx do
      canvas = construct_canvas()
      {:ok, response} = create_canvas(ctx, canvas)
      response_body = Jason.decode!(response.body)

      assert 404 == response.status_code
      api = PublicAPI.ApiSpec.spec()
      assert_schema(response_body, "Error", api)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Canvas", spec)
  end

  defp construct_canvas(params \\ %{}) do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Canvases.Canvas.schema())

    params =
      %{
        organization_id: default.metadata.organization.id,
        name: default.metadata.name
      }
      |> Map.merge(params)

    organization = %{
      id: params.organization_id,
      name: default.metadata.organization.name
    }

    default
    |> Map.put(:metadata, Map.put(default.metadata, :organization, organization))
    |> Map.put(:metadata, Map.put(default.metadata, :name, params.name))
  end

  defp create_canvas(ctx, dashboard) do
    url = url() <> "/canvases"

    body = Jason.encode!(dashboard)

    HTTPoison.post(url, body, headers(ctx))
  end
end
