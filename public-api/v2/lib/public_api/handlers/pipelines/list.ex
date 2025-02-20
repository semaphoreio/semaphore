defmodule PublicAPI.Handlers.Pipelines.List do
  @moduledoc false
  require Logger

  alias InternalClients.Pipelines, as: PipelinesClient
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Pipelines.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Pipelines.ListResponse

  plug(:recast_filters)
  # this has to be done because OpenApiSpex is currently not handling
  # exploding parameters correctly
  def recast_filters(conn, _opts) do
    new_params = conn.params |> Map.merge(conn.params.filters) |> Map.drop([:filters])
    %{conn | params: new_params}
  end

  plug(PublicAPI.Plugs.InitialPplId)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["ppl_list"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Pipelines"],
      summary: "List pipelines",
      description: "List pipelines using project id or workflow id.",
      operationId: @operation_id,
      parameters:
        [
          Operation.parameter(
            :filters,
            :query,
            %Schema{
              type: :object,
              oneOf:
                one_of(
                  schema: %Schema{
                    type: :object,
                    properties: %{
                      project_id: %Schema{
                        description: "id of the project",
                        type: :string,
                        format: :uuid,
                        example: UUID.uuid4()
                      },
                      wf_id: %Schema{
                        description: "id of a workflow",
                        type: :string,
                        format: :uuid,
                        example: UUID.uuid4()
                      }
                    }
                  },
                  combinations: [[:project_id], [:wf_id]]
                )
            },
            "The id of a project or workflow to list the pipeliens for. Either project_id or wf_id is required.
            The required_id parameter is just a placeholder",
            required: true,
            style: :form,
            explode: true
          ),
          Operation.parameter(
            :label,
            :query,
            %Schema{type: :string},
            "Label of the branch/pr/tag",
            example: "main"
          ),
          Operation.parameter(:yml_file_path, :query, %Schema{type: :string}, "Yaml file path",
            example: ".semaphore/semaphore.yml"
          ),
          Operation.parameter(
            :created_before,
            :query,
            timestamp(),
            "Return only pipelines created before this timestamp",
            example: "2021-01-01T00:00:00Z",
            style: :form,
            required: true
          ),
          Operation.parameter(
            :created_after,
            :query,
            timestamp(),
            "Return only pipelines created after this timestamp",
            example: "2021-01-01T00:00:00Z",
            style: :form,
            required: true
          ),
          Operation.parameter(
            :done_before,
            :query,
            timestamp(),
            "Return only pipelines that finished before this timestamp",
            example: "2021-01-01T00:00:00Z"
          ),
          Operation.parameter(
            :done_after,
            :query,
            timestamp(),
            "Return only pipelines that finished after this timestamp",
            example: "2021-01-01T00:00:00Z"
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
              "List of pipelines in a project or workflow",
              "application/json",
              @response_schema
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
    |> PipelinesClient.list()
    |> set_response(conn)
  end
end
