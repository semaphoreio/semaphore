defmodule Router.EventSources.CreateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)
      canvas = Support.Stubs.Canvases.create_canvas(org, name: "canvas-1")

      # TODO: update these permissions
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.manage")

      {:ok,
       %{
         org_id: org_id,
         user_id: user_id,
         org: org,
         canvas_id: canvas.id
       }}
    end

    test "create an event source", ctx do
      source =
        construct_source(%{
          organization_id: ctx.org_id,
          canvas_id: ctx.canvas_id,
          name: "source-1"
        })

      {:ok, response} = create_source(ctx, source)
      created_source = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_source)
      assert source.metadata.name == created_source["metadata"]["name"]
    end

    test "random version => fail", ctx do
      source = construct_source() |> Map.put(:apiVersion, "v3")
      {:ok, response} = create_source(ctx, source)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      source = construct_source() |> Map.put(:kind, "Foo")
      {:ok, response} = create_source(ctx, source)

      assert 422 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org = %{id: UUID.uuid4()}
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org.id)
      canvas = Support.Stubs.Canvases.create_canvas(org, name: "canvas-1")

      # TODO: update these permissions
      PermissionPatrol.add_permissions(org.id, user_id, "organization.dashboards.view")

      {:ok,
       %{
         org_id: org.id,
         user_id: user_id,
         org: org.id,
         canvas_id: canvas.id
       }}
    end

    test "create a source", ctx do
      source = construct_source()
      {:ok, response} = create_source(ctx, source)
      response_body = Jason.decode!(response.body)

      assert 404 == response.status_code
      api = PublicAPI.ApiSpec.spec()
      assert_schema(response_body, "Error", api)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "EventSource", spec)
  end

  defp construct_source(params \\ %{}) do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.EventSources.EventSource.schema())

    params =
      %{
        organization_id: default.metadata.organization.id,
        canvas_id: default.metadata.canvas.id,
        name: default.metadata.name
      }
      |> Map.merge(params)

    organization = %{
      id: params.organization_id,
      name: default.metadata.organization.name
    }

    canvas = %{
      id: params.canvas_id
    }

    default
    |> Map.put(:metadata, Map.put(default.metadata, :organization, organization))
    |> Map.put(:metadata, Map.put(default.metadata, :canvas, canvas))
    |> Map.put(:metadata, Map.put(default.metadata, :name, params.name))
  end

  defp create_source(ctx, source) do
    url = url() <> "/canvases/#{ctx.canvas_id}/sources"

    body = Jason.encode!(source)

    HTTPoison.post(url, body, headers(ctx))
  end
end
