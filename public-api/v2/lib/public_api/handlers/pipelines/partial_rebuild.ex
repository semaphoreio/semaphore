defmodule PublicAPI.Handlers.Pipelines.PartialRebuild do
  @moduledoc false

  alias InternalClients.Pipelines, as: PipelinesClient
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Pipelines.PartialRebuild"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Pipelines.PartialRebuildResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.job.rerun"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["ppl_partial_rebuild"])
  plug(PublicAPI.Handlers.Pipelines.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:partial_rebuild)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Pipelines"],
      summary: "Rebuild failed blocks of a pipeline",
      description: "Schedule a new pipeline based on given one which will only run blocks which
      execution failed in original pipeline.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :pipeline_id,
          :path,
          %Schema{
            type: :string,
            format: :uuid
          },
          "Id of the pipeline",
          required: true
        )
      ],
      requestBody:
        Operation.request_body(
          "Idempotency token",
          "application/json",
          %Schema{
            type: :object,
            properties: %{
              request_token: %Schema{
                type: :string,
                description:
                  " When partial rebuild request is received, request_token is checked first.
                   If pipeline's partial rebuild with the same request_token is already scheduled:
                   - OK and previously generated ppl_id are returned,
                     without scheduling new partial rebuild of pipeline.
                   - Other parameters are not checked; they are assumed to be the same."
              }
            },
            required: [:request_token]
          }
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Message and created pipeline id",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def partial_rebuild(conn, _opts) do
    PipelinesClient.partial_rebuild(
      conn.params.pipeline_id,
      conn.body_params.request_token,
      conn.assigns[:user_id]
    )
    |> set_response(conn)
  end
end
