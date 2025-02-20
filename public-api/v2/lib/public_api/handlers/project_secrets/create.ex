defmodule PublicAPI.Handlers.ProjectSecrets.Create do
  @moduledoc false
  require Logger

  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  plug(PublicAPI.Plugs.FeatureFlag, feature: "project_level_secrets")

  @operation_id "ProjectSecrets.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.secrets.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["create", "project_secrets"])
  plug(:create)

  def open_api_operation(_) do
    %Operation{
      tags: ["ProjectSecrets"],
      summary: "Create a project secret",
      description: "Create a project scoped secret.",
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
        )
      ],
      requestBody:
        Operation.request_body(
          "Secret to be created",
          "application/json",
          Schemas.ProjectSecrets.Secret
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created secret",
              "application/json",
              Schemas.ProjectSecrets.Secret
            )
        })
    }
  end

  def create(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.body_params
    |> Map.merge(%{
      organization_id: org_id,
      user_id: user_id,
      secret_level: :PROJECT,
      project_id: conn.assigns[:project_id]
    })
    |> SecretsClient.create()
    |> PublicAPI.Util.Response.respond(conn)
  end
end
