defmodule PublicAPI.Handlers.Workflows.Reschedule do
  @moduledoc false
  alias InternalClients.Workflow, as: WorkflowClient

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Workflows.Reschedule"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Workflows.RescheduleResponse

  plug(PublicAPI.Plugs.InitialPplId)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.job.rerun"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["wf_reschedule"])
  plug(PublicAPI.Handlers.Workflows.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:reschedule)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Workflows"],
      summary: "Rerun a workflow",
      description: "Schedule a workflow for re-running",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :wf_id,
          :path,
          %Schema{type: :string, format: :uuid},
          "Workflow id",
          example: UUID.uuid4(),
          required: true
        )
      ],
      requestBody:
        Operation.request_body(
          "Request token can be any string",
          "application/json",
          %Schema{
            type: :object,
            properties: %{
              request_token: %Schema{type: :string, format: :uuid}
            },
            required: [:request_token]
          }
        ),
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

  def reschedule(conn, _opts) do
    requester_id = conn.assigns[:user_id]

    WorkflowClient.reschedule(conn.params.wf_id, requester_id, conn.body_params.request_token)
    |> set_response(conn)
  end
end
