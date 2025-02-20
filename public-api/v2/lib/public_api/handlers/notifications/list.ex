defmodule PublicAPI.Handlers.Notifications.List do
  @moduledoc false
  require Logger

  alias InternalClients.Notifications, as: NotificationsClient
  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Notifications.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Notifications.ListResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.notifications.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["notifications_list"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Notifications"],
      summary: "List notifications",
      description: "List notifications in organization.",
      operationId: @operation_id,
      parameters: [] ++ Pagination.token_params(),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of notifications in organization",
              "application/json",
              @response_schema,
              links: Pagination.token_links(@operation_id)
            )
        })
    }
  end

  def list(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    Map.merge(conn.params, %{
      organization_id: org_id,
      user_id: user_id
    })
    |> NotificationsClient.list()
    |> add_page_size(conn.params.page_size)
    |> set_response(conn)
  end

  defp add_page_size({:ok, response}, page_size),
    do: {:ok, Map.put(response, :page_size, page_size)}

  defp add_page_size(e, _), do: e
end
