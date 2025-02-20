defmodule PublicAPI.Handlers.Workflows.List do
  @moduledoc false
  require Logger

  alias InternalClients.Workflow, as: WorkflowClient

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Workflows.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Workflows.ListResponse

  plug(PublicAPI.Plugs.InitialPplId)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["wf_list"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Workflows"],
      summary: "List workflows",
      description: "List workflows using project id.",
      operationId: @operation_id,
      parameters:
        [
          Operation.parameter(
            :project_id,
            :query,
            %Schema{type: :string, format: :uuid},
            "The id of the project to list the workflows for",
            required: true
          ),
          Operation.parameter(:branch_name, :query, %Schema{type: :string}, "Branch name",
            example: "main"
          ),
          Operation.parameter(
            :created_before,
            :query,
            %Schema{type: :string, format: :"date-time"},
            "Return only workflows created before this timestamp",
            example: "2021-01-01T00:00:00Z",
            required: true
          ),
          Operation.parameter(
            :created_after,
            :query,
            %Schema{type: :string, format: :"date-time"},
            "Return only workflows created after this timestamp",
            example: "2021-01-01T00:00:00Z",
            required: true
          ),
          Operation.parameter(
            :label,
            :query,
            %Schema{type: :string},
            "Return only workflows with given label (label is branch/tag name, PR number, snapshot generated label etc.)",
            example: "v2"
          ),
          Operation.parameter(
            :git_ref_type,
            :query,
            %Schema{type: :string, enum: ~w(BRANCH TAG PR)},
            "Type of git reference for which workflow is initiated.",
            example: "BRANCH"
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
        ] ++ Pagination.token_params(),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of workflows in a project",
              "application/json",
              @response_schema,
              links: Pagination.token_links(@operation_id)
            )
        })
    }
  end

  def list(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.params
    |> Map.merge(%{
      organization_id: org_id,
      user_id: user_id
    })
    |> WorkflowClient.list()
    |> LogTee.info("List workflows")
    |> set_response(conn)
  end
end
