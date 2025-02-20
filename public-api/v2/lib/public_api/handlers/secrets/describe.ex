defmodule PublicAPI.Handlers.Secrets.Describe do
  @moduledoc false
  require Logger

  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Secrets.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Secrets.Secret

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.secrets.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["secrets_describe"])
  plug(PublicAPI.Handlers.Secrets.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Secrets"],
      summary: "Describe an organization secret",
      description: "Describe an organization secret with md5 contents.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.id("Secret"),
              PublicAPI.Schemas.Secrets.Name.schema()
            ]
          },
          "Id or name of the secret",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Organization secret",
              "application/json",
              @response_schema
            )
        })
    }
  end

  # The secret is already loaded in the connection and respond plug will take care of the response
  def describe(conn, _opts), do: conn
end
