defmodule PublicAPI.Handlers.Notifications.Delete do
  @moduledoc false
  require Logger

  alias InternalClients.Notifications, as: NotificationsClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Notifications.Delete"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Notifications.DeleteResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.notifications.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["notifications_describe"])
  plug(PublicAPI.Handlers.Notifications.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Notifications"],
      summary: "Delete a notification",
      description: "Delete a notification.",
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
          "Id or name of the notification",
          required: true
        )
      ],
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

  def delete(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    {id, name} = get_id_and_name(conn.params.id_or_name)

    %{id: id, name: name, organization_id: org_id, user_id: user_id}
    |> NotificationsClient.destroy()
    |> set_response(conn)
  end
end
