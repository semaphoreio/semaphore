defmodule PublicAPI.Handlers.Notifications.Describe do
  @moduledoc false
  require Logger

  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Notifications.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Notifications.Notification

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.notifications.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["notifications_describe"])
  plug(PublicAPI.Handlers.Notifications.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Notifications"],
      summary: "Describe a notification",
      description: "Describe a notification.",
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

  # The notification is already loaded in the connection and respond plug will take care of the response
  def describe(conn, _opts), do: conn
end
