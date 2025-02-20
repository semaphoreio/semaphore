defmodule PublicAPI.Handlers.Dashboards.Update do
  @moduledoc false

  alias InternalClients.Dashboards, as: DashboardsClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Dashboards.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Dashboards.Dashboard

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["dashboards_update"])

  plug(PublicAPI.Handlers.Dashboards.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Dashboards"],
      summary: "Update a dashboard",
      description: "Update a dashboard by its id or name.",
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
      requestBody:
        Operation.request_body(
          "Dashboard to be updated",
          "application/json",
          Schemas.Dashboards.Dashboard
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Updated dashboard",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def update(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    org_name = conn.assigns[:organization_username]
    user_id = conn.assigns[:user_id]

    ctx = %{
      organization: %{
        id: org_id,
        name: org_name
      }
    }

    conn.body_params
    |> Map.merge(%{organization_id: org_id, user_id: user_id, id_or_name: conn.params.id_or_name})
    |> DashboardsClient.update()
    |> case do
      {:ok, dashboard} ->
        dashboard
        |> PublicAPI.Handlers.Dashboards.Formatter.describe(ctx)
        |> set_response(conn)

      {:error, _} = error ->
        error
        |> set_response(conn)
    end
  end
end
