defmodule PublicAPI.Handlers.Canvases.Describe do
  @moduledoc false
  require Logger

  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Canvases.Describe"
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
    permissions: ["organization.dashboards.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["describe", "canvas"])

  plug(PublicAPI.Handlers.Canvases.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Canvas"],
      summary: "Describe a canvas",
      description: "Describe a canvas by its id or name.",
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
          "Id or name of the canvas",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Canvas",
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
