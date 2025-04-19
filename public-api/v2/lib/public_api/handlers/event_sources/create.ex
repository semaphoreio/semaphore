defmodule PublicAPI.Handlers.EventSources.Create do
  @moduledoc false

  alias InternalClients.Canvases, as: CanvasesClient
  alias PublicAPI.Handlers.EventSources.Formatter
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "EventSources.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.EventSources.EventSource

  plug(PublicAPI.Plugs.CanvasIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    # TODO: use a proper permission here, like "organization.canvases.manage".
    # For now, I'm using an existing one because I don't want to create a new one permission yet.
    permissions: ["organization.dashboards.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["create", "event_source"])
  plug(:create)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["EventSource"],
      summary: "Create an event source",
      description: "Create an event source.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :canvas_id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.ResourceId.schema(),
              PublicAPI.Schemas.Common.Name.schema()
            ]
          },
          "Id or name of the canvas",
          required: true
        )
      ],
      requestBody:
        Operation.request_body(
          "Event source to be created",
          "application/json",
          Schemas.EventSources.EventSource
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created event source",
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
      user_id: user_id,
      canvas_id: conn.params.canvas_id
    })
    |> CanvasesClient.create_event_source()
    |> case do
      {:ok, response} ->
        Formatter.describe(ctx, response.event_source, response.key)
        |> set_response(conn)

      {:error, _} = error ->
        error
        |> set_response(conn)
    end
  end
end
