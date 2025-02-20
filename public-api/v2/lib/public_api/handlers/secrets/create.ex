defmodule PublicAPI.Handlers.Secrets.Create do
  @moduledoc false
  require Logger

  alias InternalClients.Permissions, as: PermissionsClient
  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Secrets.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.secrets.manage"]
  )

  plug(PublicAPI.Plugs.AuditLogger)

  plug(PublicAPI.Plugs.Metrics, tags: ["secrets_create"])
  plug(:create)

  def open_api_operation(_) do
    %Operation{
      tags: ["Secrets"],
      summary: "Create an organization secret",
      description: "Create an organization secret.",
      operationId: @operation_id,
      parameters: [],
      requestBody:
        Operation.request_body(
          "Secret to be created",
          "application/json",
          Schemas.Secrets.Secret
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created secret",
              "application/json",
              Schemas.Secrets.Secret
            )
        })
    }
  end

  def create(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

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

    conn.body_params
    |> Map.put(:access_config, org_config)
    |> Map.merge(%{organization_id: org_id, user_id: user_id, secret_level: :ORGANIZATION})
    |> SecretsClient.create()
    |> PublicAPI.Util.Response.respond(conn)
  end
end
