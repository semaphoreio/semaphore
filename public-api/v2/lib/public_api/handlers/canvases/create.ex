defmodule PublicAPI.Handlers.Canvases.Create do
  @moduledoc false
  require Logger

  alias InternalClients.Canvases, as: CanvasesClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Canvases.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Canvases.Canvas

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    # TODO: use a proper permission here, like "organization.canvases.manage".
    # For now, I'm using an existing one because I don't want to create a new one permission yet.
    permissions: ["organization.dashboards.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["create", "canvas"])
  plug(:create)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Canvases"],
      summary: "Create a canvas",
      description: "Create a canvas.",
      operationId: @operation_id,
      parameters: [],
      requestBody:
        Operation.request_body(
          "Canvas to be created",
          "application/json",
          Schemas.Canvases.Canvas
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created canvas",
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
    |> CanvasesClient.create_canvas()
    |> case do
      {:ok, canvas} ->
        canvas
        |> PublicAPI.Handlers.Canvases.Formatter.describe(ctx)
        |> set_response(conn)

      {:error, _} = error ->
        error
        |> set_response(conn)
    end
  end
end
