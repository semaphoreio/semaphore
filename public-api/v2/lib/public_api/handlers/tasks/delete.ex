defmodule PublicAPI.Handlers.Tasks.Delete do
  @moduledoc false
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.Schedulers, as: Client

  @operation_id "Tasks.Delete"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Tasks.Task

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.scheduler.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["tasks_delete"])

  plug(PublicAPI.Plugs.ContentType, "application/json")

  plug(PublicAPI.Handlers.Tasks.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Tasks"],
      summary: "Delete a task",
      description: "Delete a task by given ID",
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
          200 => Operation.response("Task Deleted", "application/json", @response_schema)
        })
    }
  end

  def delete(conn, _opts) do
    conn.params
    |> Map.put(:requester_id, conn.assigns[:user_id])
    |> Client.delete()
    |> set_response(conn)
  end
end
