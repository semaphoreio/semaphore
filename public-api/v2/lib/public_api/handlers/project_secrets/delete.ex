defmodule PublicAPI.Handlers.ProjectSecrets.Delete do
  @moduledoc false
  require Logger

  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  plug(PublicAPI.Plugs.FeatureFlag, feature: "project_level_secrets")

  @operation_id "ProjectSecrets.Delete"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Secrets.DeleteResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.secrets.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["delete", "project_secrets"])
  plug(PublicAPI.Handlers.Secrets.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["ProjectSecrets"],
      summary: "Delete a project secret",
      description: "Delete a project secret.",
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

    %{
      id: id,
      name: name,
      organization_id: org_id,
      user_id: user_id,
      secret_level: :PROJECT,
      project_id: conn.assigns[:project_id]
    }
    |> SecretsClient.delete()
    |> set_response(conn)
  end
end
