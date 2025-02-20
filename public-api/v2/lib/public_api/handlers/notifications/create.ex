defmodule PublicAPI.Handlers.Notifications.Create do
  @moduledoc false
  require Logger

  alias InternalClients.Notifications, as: NotificationsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Notifications.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.notifications.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["notifications_create"])
  plug(:create)

  def open_api_operation(_) do
    %Operation{
      tags: ["Notifications"],
      summary: "Create a notification",
      description: "Create a notification.",
      operationId: @operation_id,
      parameters: [],
      requestBody:
        Operation.request_body(
          "Notification to be created",
          "application/json",
          Schemas.Notifications.Notification
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Notification",
              "application/json",
              Schemas.Notifications.Notification
            )
        })
    }
  end

  def create(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.body_params
    |> Map.merge(%{organization_id: org_id, user_id: user_id})
    |> NotificationsClient.create()
    |> PublicAPI.Util.Response.respond(conn)
  end
end
