defmodule PublicAPI.Handlers.Dashboards.Describe do
  @moduledoc false
  require Logger

  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Dashboards.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Dashboards.Dashboard

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["dashboards_describe"])

  plug(PublicAPI.Handlers.Dashboards.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Dashboards"],
      summary: "Describe a dashboard ",
      description: "Describe a dashboard by its id or name.",
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
          200 =>
            Operation.response(
              "Dashboard",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def describe(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    org_name = conn.assigns[:organization_username]

    ctx = %{
      allow_all_projects: true,
      organization: %{
        id: org_id,
        name: org_name
      }
    }

    conn
    |> get_resource()
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
