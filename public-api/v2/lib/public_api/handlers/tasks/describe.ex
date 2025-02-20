defmodule PublicAPI.Handlers.Tasks.Describe do
  @moduledoc false
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Tasks.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Tasks.Task

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.scheduler.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["tasks_describe"])
  plug(PublicAPI.Plugs.ContentType, "application/json")
  plug(PublicAPI.Handlers.Tasks.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Tasks"],
      summary: "Describe a task",
      description: "Describe a task by given ID",
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
          :task_id,
          :path,
          PublicAPI.Schemas.Common.id("Task"),
          "Task ID",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 => Operation.response("Task", "application/json", @response_schema)
        })
    }
  end

  def call(conn, opts), do: super(conn, opts)
end
