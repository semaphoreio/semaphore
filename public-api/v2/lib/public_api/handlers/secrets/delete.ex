defmodule PublicAPI.Handlers.Secrets.Delete do
  @moduledoc false
  require Logger

  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Secrets.Delete"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Secrets.DeleteResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.secrets.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["secrets_delete"])
  plug(PublicAPI.Handlers.Secrets.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Secrets"],
      summary: "Delete an organization secret",
      description: "Delete an organization secret.",
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
              "ID of the deleted secret",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def delete(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    {id, name} = get_id_and_name(conn.params.id_or_name)

    %{id: id, name: name, organization_id: org_id, user_id: user_id, secret_level: :ORGANIZATION}
    |> SecretsClient.delete()
    |> set_response(conn)
  end
end
