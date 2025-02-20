defmodule PublicAPI.Handlers.Projects.Update do
  @moduledoc false
  require Logger

  alias InternalClients.Projecthub, as: ProjectsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Projects.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Projects.Project

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.general_settings.manage", "project.repository_info.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["update", "project"])
  plug(PublicAPI.Handlers.Projects.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Projects"],
      summary: "Update a project settigns",
      description: "Update a project.",
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
          "Updated secret, only spec can be updated",
          "application/json",
          Schemas.Projects.Project
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

    conn.body_params
    |> Map.merge(%{
      organization_id: org_id,
      user_id: user_id
    })
    |> ProjectsClient.update()
    |> set_response(conn)
  end
end
