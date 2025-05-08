defmodule Router.Stages.UpdateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)
      canvas = Support.Stubs.Canvases.create_canvas(org, name: "canvas-1")
      source = Support.Stubs.Canvases.create_source(org, canvas.id, name: "source-1")
      stage = Support.Stubs.Canvases.create_stage(org, canvas.id, name: "stage-1")

      # TODO: update these permissions
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.manage")

      {:ok,
       %{
         org_id: org_id,
         user_id: user_id,
         org: org,
         canvas_id: canvas.id,
         source_id: source.id,
         source_name: source.name,
         stage_id: stage.id
       }}
    end

    test "update a stage", ctx do
      stage =
        construct_stage(%{
          organization_id: ctx.org_id,
          canvas_id: ctx.canvas_id,
          name: "stage-1",
          source_name: ctx.source_name
        })

      {:ok, response} = update_stage(ctx, stage)
      updated_stage = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(updated_stage)
      assert stage.metadata.name == updated_stage["metadata"]["name"]
    end

    test "random version => fail", ctx do
      stage = construct_stage() |> Map.put(:apiVersion, "v3")
      {:ok, response} = update_stage(ctx, stage)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      stage = construct_stage() |> Map.put(:kind, "Foo")
      {:ok, response} = update_stage(ctx, stage)

      assert 422 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org = %{id: UUID.uuid4()}
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org.id)
      canvas = Support.Stubs.Canvases.create_canvas(org, name: "canvas-1")
      source = Support.Stubs.Canvases.create_source(org, canvas.id, name: "source-1")
      stage = Support.Stubs.Canvases.create_stage(org, canvas.id, name: "stage-1")

      # TODO: update these permissions
      PermissionPatrol.add_permissions(org.id, user_id, "organization.dashboards.view")

      {:ok,
       %{
         org_id: org.id,
         user_id: user_id,
         org: org.id,
         canvas_id: canvas.id,
         source_id: source.id,
         stage_id: stage.id
       }}
    end

    test "update a stage", ctx do
      stage = construct_stage()
      {:ok, response} = update_stage(ctx, stage)
      response_body = Jason.decode!(response.body)

      assert 404 == response.status_code
      api = PublicAPI.ApiSpec.spec()
      assert_schema(response_body, "Error", api)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Stage", spec)
  end

  defp construct_stage(params \\ %{}) do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Stages.Stage.schema())

    params =
      %{
        organization_id: default.metadata.organization.id,
        canvas_id: default.metadata.canvas.id,
        name: default.metadata.name,
        source_name: ""
      }
      |> Map.merge(params)

    organization = %{
      id: params.organization_id,
      name: default.metadata.organization.name
    }

    canvas = %{
      id: params.canvas_id
    }

    connection = hd(default.spec.connections)
    filter = hd(connection.filters)

    filters = [
      %{filter | data: %{expression: "ref_type == 'tag'"}}
    ]

    connections = [
      %{connection | name: params.source_name, type: "EVENT_SOURCE", filters: filters}
    ]

    default
    |> Map.put(:metadata, Map.put(default.metadata, :organization, organization))
    |> Map.put(:metadata, Map.put(default.metadata, :canvas, canvas))
    |> Map.put(:metadata, Map.put(default.metadata, :name, params.name))
    |> Map.put(:spec, Map.put(default.spec, :connections, connections))
  end

  defp update_stage(ctx, stage) do
    url = url() <> "/canvases/#{ctx.canvas_id}/stages/#{ctx.stage_id}"

    body = Jason.encode!(stage)

    HTTPoison.put(url, body, headers(ctx))
  end
end
