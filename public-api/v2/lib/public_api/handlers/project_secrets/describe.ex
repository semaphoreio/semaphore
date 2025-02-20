defmodule PublicAPI.Handlers.ProjectSecrets.Describe do
  @moduledoc false
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  plug(PublicAPI.Plugs.FeatureFlag, feature: "project_level_secrets")

  @operation_id "ProjectSecrets.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.ProjectSecrets.Secret

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.secrets.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["describe", "project_secrets"])
  plug(PublicAPI.Handlers.Secrets.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["ProjectSecrets"],
      summary: "Describe a project scoped secret",
      description: "Describe project secret with md5 contents.",
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
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Project secret",
              "application/json",
              @response_schema
            )
        })
    }
  end

  # The secret is already loaded in the connection and respond plug will take care of the response
  def describe(conn, _opts), do: conn
end
