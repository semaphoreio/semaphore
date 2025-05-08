defmodule PublicAPI.Handlers.Stages.Update do
  @moduledoc false

  alias InternalClients.Canvases, as: CanvasesClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Stages.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Stages.Stage

  plug(PublicAPI.Plugs.CanvasIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    # TODO: use a proper permission here, like "organization.canvases.manage".
    # For now, I'm using an existing one because I don't want to create a new one permission yet.
    permissions: ["organization.dashboards.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["update", "stage"])
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Stage"],
      summary: "Update a stage",
      description: "Update a stage.",
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
        ),
        Operation.parameter(
          :id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.ResourceId.schema(),
              PublicAPI.Schemas.Common.Name.schema()
            ]
          },
          "Id or name of the stage",
          required: true
        )
      ],
      requestBody:
        Operation.request_body(
          "Stage to be updated",
          "application/json",
          Schemas.Stages.Stage
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Updated stage",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def update(conn, _opts) do
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
      id: conn.params.id_or_name,
      organization_id: org_id,
      user_id: user_id,
      canvas_id: conn.params.canvas_id_or_name
    })
    |> CanvasesClient.update_stage()
    |> case do
      {:ok, stage} ->
        stage
        |> PublicAPI.Handlers.Stages.Formatter.describe(ctx)
        |> set_response(conn)

      {:error, _} = error ->
        error
        |> set_response(conn)
    end
  end
end
