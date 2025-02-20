defmodule PublicAPI.Handlers.Secrets.Update do
  @moduledoc false
  require Logger

  alias InternalClients.Permissions, as: PermissionsClient
  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Secrets.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Secrets.Secret

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.secrets.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["secrets_update"])
  plug(PublicAPI.Handlers.Secrets.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Secrets"],
      summary: "Update an organization secret",
      description: "Update an organization secret.",
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
      requestBody:
        Operation.request_body(
          "Updated secret, only spec can be updated",
          "application/json",
          Schemas.Secrets.Secret
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Updated secret",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def update(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    id = get_resource_id(conn)

    org_config =
      if FeatureProvider.feature_enabled?("secrets_access_policy", param: org_id) &&
           PermissionsClient.has?(
             user_id,
             org_id,
             "organization.secrets_policy_settings.manage"
           ) do
        conn.body_params.spec.access_config
      else
        nil
      end

    if id != "" do
      conn.body_params
      |> Map.put(:access_config, org_config)
      |> Map.merge(%{
        id: id,
        organization_id: org_id,
        user_id: user_id,
        secret_level: :ORGANIZATION
      })
      |> SecretsClient.update()
    else
      {:error, {:user, "Secret with provided id/name not found"}}
    end
    |> set_response(conn)
  end
end
