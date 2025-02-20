defmodule PublicAPI.Handlers.Tasks.List do
  @moduledoc false
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.Schedulers, as: Client

  @operation_id "Tasks.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Tasks.ListResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.scheduler.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["tasks_list"])
  plug(PublicAPI.Plugs.ContentType, "application/json")
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Tasks"],
      summary: "List tasks",
      description: "List tasks for organization and/or project ID",
      operationId: @operation_id,
      parameters:
        [
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
            :name,
            :query,
            %Schema{type: :string},
            "Search string for task name"
          ),
          Operation.parameter(
            :direction,
            :query,
            %Schema{
              type: :string,
              description: "Use NEXT with value of next_page_token to get next page of results,
              use PREVIOUS with value of previous_page_token to get previous page of results.",
              enum: ["NEXT", "PREVIOUS"],
              default: "NEXT"
            },
            "Direction of the list from the provided token"
          )
        ] ++
          PublicAPI.SpecHelpers.Pagination.token_params(),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of tasks",
              "application/json",
              @response_schema,
              links: Pagination.token_links(@operation_id)
            )
        })
    }
  end

  def list(conn, _opts) do
    conn.params
    |> Map.put(:organization_id, conn.assigns[:organization_id])
    |> Map.put(:project_id, conn.assigns[:project_id])
    |> Client.list_keyset()
    |> set_response(conn)
  end
end
