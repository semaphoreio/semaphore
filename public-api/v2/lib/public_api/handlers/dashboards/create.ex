defmodule PublicAPI.Handlers.Dashboards.Create do
  @moduledoc false
  require Logger

  alias InternalClients.Dashboards, as: DashboardsClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Dashboards.Create"
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

  plug(PublicAPI.Plugs.Metrics, tags: ["create", "dashboard"])
  plug(:create)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Dashboards"],
      summary: "Create a dashboard",
      description: "Create a dashboard.",
      operationId: @operation_id,
      parameters: [],
      requestBody:
        Operation.request_body(
          "Dashboard to be created",
          "application/json",
          Schemas.Dashboards.Dashboard
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created dashboard",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def create(conn, _opts) do
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
    |> Map.merge(%{
      organization_id: org_id,
      user_id: user_id
    })
    |> DashboardsClient.create()
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
