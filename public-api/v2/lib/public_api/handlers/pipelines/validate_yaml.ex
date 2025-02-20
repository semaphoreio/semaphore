defmodule PublicAPI.Handlers.Pipelines.ValidateYaml do
  @moduledoc false

  require Logger

  alias InternalClients.Pipelines, as: PipelinesClient
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Pipelines.ValidateYaml"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: "Pipelines.PartialRebuild",
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["ppl_validate_yaml"])
  plug(:validate_yaml)

  def open_api_operation(_) do
    %Operation{
      tags: ["Pipelines"],
      summary: "Validate passed yaml definition against yaml schema.",
      description: "",
      operationId: @operation_id,
      parameters: [],
      requestBody:
        Operation.request_body(
          "Json containing a YAML file to be validated",
          "application/json",
          %Schema{
            type: :object,
            properties: %{
              yml_definition: %Schema{
                type: :string,
                description: "Pipeline YAML definition, be careful to escape the contents"
              }
            },
            required: [:yml_definition]
          }
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Valid YAML response, check out 400 response as well.",
              "application/json",
              %Schema{
                type: :object,
                properties: %{
                  message: %Schema{type: :string, example: "YAML definition is valid."}
                }
              }
            ),
          400 =>
            Operation.response(
              "Message explaining the errors in YAML",
              "application/json",
              %Schema{
                type: :object,
                properties: %{
                  message: %Schema{type: :string}
                }
              }
            )
        })
    }
  end

  def validate_yaml(conn, _opts) do
    conn.body_params.yml_definition
    |> PipelinesClient.validate_yaml()
    |> PublicAPI.Util.Response.respond(conn)
  end
end
