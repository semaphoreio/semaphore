defmodule PublicAPI.Handlers.Pipelines.Describe do
  @moduledoc false
  require Logger

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Pipelines.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Pipelines.DescribeResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["ppl_describe"])
  plug(PublicAPI.Handlers.Pipelines.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Pipelines"],
      summary: "Describe a pipeline and blocks within it",
      description: "Describe a pipeline using pipeline_id",
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
        ),
        Operation.parameter(
          :detailed,
          :query,
          %Schema{
            type: :boolean,
            default: false
          },
          "Option to include all information about all blocks and jobs.
           This option is much more expensive--if you are only interested in the status of a pipeline, don't set detailed to true."
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Pipeline status optionally containing information about all blocks and jobs in the pipeline.",
              "application/json",
              @response_schema
            )
        })
    }
  end

  # The pipeline is already loaded in the connection and respond plug will take care of the response
  def describe(conn, _opts), do: conn
end
