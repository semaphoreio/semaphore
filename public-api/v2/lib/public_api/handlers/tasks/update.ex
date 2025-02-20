defmodule PublicAPI.Handlers.Tasks.Update do
  @moduledoc false

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.Schedulers, as: Client

  @operation_id "Tasks.Update"
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

  plug(PublicAPI.Plugs.Metrics, tags: ["tasks_update"])
  plug(PublicAPI.Plugs.ContentType, "application/json")
  plug(PublicAPI.Handlers.Tasks.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Tasks"],
      summary: "Update a task",
      description: "Update (patch) task with given params",
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
      requestBody:
        Operation.request_body(
          "",
          "application/json",
          %Schema{
            description: "Task Update request body",
            type: :object,
            properties: %{
              apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
              kind: PublicAPI.Schemas.Tasks.Task.ResourceKind.schema(),
              spec: %{PublicAPI.Schemas.Tasks.Spec.schema() | required: []}
            },
            required: [:apiVersion, :kind, :spec]
          }
        ),
      responses:
        Responses.with_errors(%{
          200 => Operation.response("Task", "application/json", @response_schema)
        })
    }
  end

  def update(conn, _opts) do
    conn
    |> get_resource()
    |> case do
      {:ok, task} ->
        conn.body_params[:spec]
        |> merge_task_fields(task.spec)
        |> Map.put(:requester_id, conn.assigns[:user_id])
        |> Map.put(:task_id, conn.params[:task_id])
        |> Client.persist()
        |> set_response(conn)

      {:error, _reason} = error ->
        error |> set_response(error)
    end
  end

  defp merge_task_fields(params, task) do
    params
    |> Map.from_struct()
    |> Enum.into(task, fn
      {key, nil} -> {key, task[key]}
      {key, value} -> {key, value}
    end)
  end
end
