defmodule PublicAPI.Handlers.ProjectSecrets.Update do
  @moduledoc false
  require Logger

  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  plug(PublicAPI.Plugs.FeatureFlag, feature: "project_level_secrets")

  @operation_id "ProjectSecrets.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.ProjectSecrets.Secret

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.secrets.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["update", "project_secrets"])
  plug(PublicAPI.Handlers.ProjectSecrets.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["ProjectSecrets"],
      summary: "Update a project secret",
      description: "Update a project scoped secret.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :project_id_or_name,
          :path,
          %Schema{
            anyOf: [
              PublicAPI.Schemas.Common.id("Project"),
              PublicAPI.Schemas.Projects.Name.schema()
            ]
          },
          "Id or name of the project",
          required: true
        ),
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

    conn.body_params
    |> Map.merge(%{
      id: id,
      organization_id: org_id,
      user_id: user_id,
      secret_level: :PROJECT,
      project_id: conn.assigns[:project_id]
    })
    |> SecretsClient.update()
    |> set_response(conn)
  end
end
