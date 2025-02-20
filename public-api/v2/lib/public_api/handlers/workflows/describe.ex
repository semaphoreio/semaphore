defmodule PublicAPI.Handlers.Workflows.Describe do
  @moduledoc false

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Workflows.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Workflows.Workflow

  plug(PublicAPI.Plugs.InitialPplId)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["wf_describe"])
  plug(PublicAPI.Handlers.Workflows.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Workflows"],
      summary: "Describe a workflow",
      description: "Describe a workflow based on workflow id",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :wf_id,
          :path,
          Schemas.Common.id("Workflow"),
          "Workflow id",
          example: UUID.uuid4()
        )
      ],
      responses:
        Responses.with_errors(%{
          200 => Operation.response("Workflow", "application/json", @response_schema)
        })
    }
  end

  # The workflow is already loaded in the connection and respond plug will take care of the response
  def describe(conn, _opts), do: conn
end
