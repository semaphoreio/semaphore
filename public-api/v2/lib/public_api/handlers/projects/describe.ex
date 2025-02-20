defmodule PublicAPI.Handlers.Projects.Describe do
  @moduledoc false

  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Projects.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Projects.Project
  @resource_key :project

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["describe", "project"])
  plug(PublicAPI.Handlers.Projects.Loader, key: @resource_key)
  plug(PublicAPI.Plugs.ObjectFilter, key: @resource_key)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond, schema: @response_schema, key: @resource_key)

  def open_api_operation(_) do
    %Operation{
      tags: ["Projects"],
      summary: "Describe a project",
      description: "Describe project.",
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
              "Project",
              "application/json",
              @response_schema
            )
        })
    }
  end

  # The project is already loaded in the connection and respond plug will take care of the response
  def describe(conn, _opts), do: conn
end
