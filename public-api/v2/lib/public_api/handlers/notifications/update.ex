defmodule PublicAPI.Handlers.Notifications.Update do
  @moduledoc false
  require Logger

  alias InternalClients.Notifications, as: NotificationsClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Notifications.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Notifications.Notification

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.notifications.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["notifications_update"])
  plug(PublicAPI.Handlers.Notifications.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Notifications"],
      summary: "Update a notification",
      description: "Update a notification.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.id("Notification"),
              %Schema{
                type: :string,
                description: "Name of the notification"
              }
            ]
          },
          "Id or name of the notification to update",
          required: true
        )
      ],
      requestBody:
        Operation.request_body(
          "Notification",
          "application/json",
          Schemas.Notifications.Notification
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Notification",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def update(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    {id, name} = get_id_and_name(conn.params.id_or_name)

    conn.body_params
    |> Map.merge(%{id: id, name: name, organization_id: org_id, user_id: user_id})
    |> NotificationsClient.update()
    |> set_response(conn)
  end
end
