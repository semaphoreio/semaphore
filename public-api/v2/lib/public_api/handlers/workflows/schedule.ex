defmodule PublicAPI.Handlers.Workflows.Schedule do
  @moduledoc false
  require Logger

  alias InternalClients.RepoProxy, as: RepoProxyClient

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Workflows.Schedule"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    replace_params: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Workflows.ScheduleResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.job.rerun"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["wf_schedule"])
  plug(PublicAPI.Handlers.Projects.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(:schedule)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Workflows"],
      summary: "Schedule a workflow",
      description: "Schedule a workflow for running",
      operationId: @operation_id,
      requestBody:
        Operation.request_body(
          "Workflow schedule parameters",
          "application/json",
          Schemas.Workflows.Schedule
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def schedule(conn, _opts) do
    user_id = conn.assigns[:user_id]

    conn.body_params
    |> Map.merge(%{requester_id: user_id})
    |> RepoProxyClient.create()
    |> LogTee.info("Workflow scheduled")
    |> set_response(conn)
  end
end
