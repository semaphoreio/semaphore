defmodule PublicAPI.Handlers.Workflows.Terminate do
  @moduledoc false
  require Logger

  alias InternalClients.Workflow, as: WorkflowClient

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Workflows.Terminate"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Workflows.TerminateResponse

  plug(PublicAPI.Plugs.InitialPplId)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.job.stop"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["wf_terminate"])
  plug(PublicAPI.Handlers.Workflows.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:terminate)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Workflows"],
      summary: "Stopping a workflow",
      description: "Stop a scheduled workflow",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :wf_id,
          :path,
          Schemas.Common.id("Workflow"),
          "Workflow id",
          example: UUID.uuid4(),
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def terminate(conn, _opts) do
    requester_id = conn.assigns[:user_id]

    WorkflowClient.terminate(conn.params.wf_id, requester_id)
    |> set_response(conn)
  end
end
