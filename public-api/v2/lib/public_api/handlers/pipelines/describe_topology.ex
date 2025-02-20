defmodule PublicAPI.Handlers.Pipelines.DescribeTopology do
  @moduledoc false

  require Logger

  alias InternalClients.Pipelines, as: PipelinesClient
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Pipelines.DescribeTopology"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Pipelines.DescribeTopologyResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["ppl_describe_topology"])
  plug(PublicAPI.Handlers.Pipelines.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe_topology)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Pipelines"],
      summary: "Describe a pipeline topology",
      description: "Describe pipeline topology using pipeline_id",
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

  def describe_topology(conn, _opts) do
    PipelinesClient.describe_topology(conn.params.pipeline_id)
    |> set_response(conn)
  end
end
