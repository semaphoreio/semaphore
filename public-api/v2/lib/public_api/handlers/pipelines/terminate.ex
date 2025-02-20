defmodule PublicAPI.Handlers.Pipelines.Terminate do
  @moduledoc false

  alias PublicAPI.Util.ToTuple
  alias InternalClients.Pipelines, as: PipelinesClient

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Pipelines.Terminate"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Pipelines.TerminateResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.job.stop"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["ppl_terminate"])
  plug(PublicAPI.Handlers.Pipelines.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:terminate)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Pipelines"],
      summary: "Terminate a pipeline",
      description: "Terminate a pipeline using pipeline_id",
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
          "Must set terminate request to true",
          "application/json",
          %Schema{
            type: :object,
            properties: %{
              terminate_request: %Schema{
                type: :boolean
              }
            },
            required: [:terminate_request]
          }
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Pipeline topology",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def terminate(conn, _opts) do
    case Map.get(conn.body_params, :terminate_request) do
      true ->
        conn.params.pipeline_id |> PipelinesClient.terminate()

      _ ->
        %{message: "Value of 'terminate_request' field must be explicitly set to 'true'."}
        |> ToTuple.user_error()
    end
    |> set_response(conn)
  end
end
