defmodule PublicAPI.Handlers.Projects.Delete do
  @moduledoc false
  require Logger

  alias InternalClients.Projecthub, as: ProjectsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Projects.Delete"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Projects.DeleteResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.delete"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["delete", "project"])
  plug(PublicAPI.Handlers.Projects.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Projects"],
      summary: "Delete a project",
      description: "Delete a project.",
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
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "ID of the deleted project",
              "application/json",
              Schemas.Projects.DeleteResponse
            )
        })
    }
  end

  def delete(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.params
    |> Map.merge(%{
      organization_id: org_id,
      user_id: user_id,
      project_id: conn.assigns[:project_id]
    })
    |> ProjectsClient.delete()
    |> inject_project_id(conn)
    |> set_response(conn)
  end

  defp inject_project_id(response, conn) do
    case response do
      {:ok, _} -> {:ok, %{project_id: conn.assigns[:project_id]}}
      _ -> response
    end
  end
end
