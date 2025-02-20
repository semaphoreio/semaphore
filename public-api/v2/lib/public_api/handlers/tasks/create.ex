defmodule PublicAPI.Handlers.Tasks.Create do
  @moduledoc false
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  alias InternalClients.Schedulers, as: Client
  alias PublicAPI.Util.Response

  @operation_id "Tasks.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.scheduler.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["tasks_create"])
  plug(PublicAPI.Plugs.ContentType, "application/json")

  def open_api_operation(_) do
    %Operation{
      tags: ["Tasks"],
      summary: "Create a task",
      description: "Create a task from given params",
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
          "",
          "application/json",
          %Schema{
            title: "Task.CreateRequestBody",
            description: "Task Create request body",
            type: :object,
            properties: %{
              apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
              kind: PublicAPI.Schemas.Tasks.Task.ResourceKind.schema(),
              spec: PublicAPI.Schemas.Tasks.Spec.schema()
            },
            required: [:apiVersion, :kind, :spec]
          }
        ),
      responses:
        Responses.with_errors(%{
          200 => Operation.response("Task", "application/json", Schemas.Tasks.Task)
        })
    }
  end

  def call(conn, opts) do
    conn = super(conn, opts)

    conn.body_params[:spec]
    |> Map.put(:organization_id, conn.assigns[:organization_id])
    |> Map.put(:requester_id, conn.assigns[:user_id])
    |> Map.put(:project_id, conn.assigns[:project_id])
    |> Client.persist()
    |> Response.respond(conn)
  end
end
