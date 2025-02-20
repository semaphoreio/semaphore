defmodule PublicAPI.Handlers.Dashboards.Delete do
  @moduledoc false
  require Logger

  alias InternalClients.Dashboards, as: DashboardsClient

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Dashboards.Delete"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema nil

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["dashboards_delete"])

  plug(PublicAPI.Handlers.Dashboards.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Dashboards"],
      summary: "Delete a dashboard",
      description: "Delete a dashboard by its id or name.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.ResourceId.schema(),
              PublicAPI.Schemas.Common.Name.schema()
            ]
          },
          "Id or name of the dashboard",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          204 => %OpenApiSpex.Response{description: "No content"}
        })
    }
  end

  def delete(conn, _opts) do
    {:ok, dashboard} = get_resource(conn)

    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    %{id_or_name: dashboard.metadata.id, organization_id: org_id, user_id: user_id}
    |> DashboardsClient.delete()
    |> set_response(conn)
  end
end
