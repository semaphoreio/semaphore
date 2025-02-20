defmodule PublicAPI.Handlers.Projects.Create do
  @moduledoc false
  require Logger

  alias InternalClients.Projecthub, as: ProjectsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Projects.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.projects.create"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["create", "project"])
  plug(:create)

  def open_api_operation(_) do
    %Operation{
      tags: ["Projects"],
      summary: "Create a project",
      description: "Create a project. When creating a project description is ignored.",
      operationId: @operation_id,
      parameters: [],
      requestBody:
        Operation.request_body(
          "Project to be created",
          "application/json",
          Schemas.Projects.Project
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created project",
              "application/json",
              Schemas.Projects.Project
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
      user_id: user_id
    })
    |> ProjectsClient.create()
    |> PublicAPI.Util.Response.respond(conn)
  end
end
