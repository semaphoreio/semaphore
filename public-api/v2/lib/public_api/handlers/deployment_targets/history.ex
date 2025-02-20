defmodule PublicAPI.Handlers.DeploymentTargets.History do
  @moduledoc """
  Plug history of a deployment target triggers.
  """

  alias InternalClients.DeploymentTargets, as: DTClient
  alias PublicAPI.Schemas

  import PublicAPI.Handlers.DeploymentTargets.Plugs.Common,
    only: [has_deployment_targets_enabled: 2, remove_sensitive_params: 2]

  import PublicAPI.Handlers.DeploymentTargets.Util.ErrorHandler

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  require Logger

  plug(:remove_sensitive_params)
  plug(:has_deployment_targets_enabled)

  @operation_id "DeploymentTargets.History"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.DeploymentTargets.HistoryResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.deployment_targets.view"]
  )

  plug(PublicAPI.Plugs.SecretsKey)

  plug(PublicAPI.Plugs.Metrics, tags: ["history", "deployment_targets"])

  plug(PublicAPI.Handlers.DeploymentTargets.Plugs.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:history)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["DeploymentTargets"],
      summary: "History of a project deployment target",
      description:
        "This endpoint provides the deployment history for a specific deployment target.",
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
            :id_or_name,
            :path,
            %Schema{
              type: :string,
              description: "Id or name of the deployment target"
            },
            "Id or name of the deployment target",
            required: true
          ),
          Operation.parameter(
            :git_ref_type,
            :query,
            %Schema{
              type: :string,
              description: "Git reference type"
            },
            "Git reference type"
          ),
          Operation.parameter(
            :git_ref_label,
            :query,
            %Schema{
              type: :string,
              description: "Git reference label"
            },
            "Git reference label"
          ),
          Operation.parameter(
            :triggered_by,
            :query,
            %Schema{
              type: :string,
              description: "Triggerer ID or value"
            },
            "Triggerer ID or value"
          ),
          Operation.parameter(
            :parameter1,
            :query,
            %Schema{
              type: :string,
              description: "Value of promotion parameter with the name from bookmark slot #1"
            },
            "Value of promotion parameter with the name from bookmark slot #1"
          ),
          Operation.parameter(
            :parameter2,
            :query,
            %Schema{
              type: :string,
              description: "Value of promotion parameter with the name from bookmark slot #2"
            },
            "Value of promotion parameter with the name from bookmark slot #2"
          ),
          Operation.parameter(
            :parameter3,
            :query,
            %Schema{
              type: :string,
              description: "Value of promotion parameter with the name from bookmark slot #3"
            },
            "Value of promotion parameter with the name from bookmark slot #3"
          ),
          Operation.parameter(
            :direction,
            :query,
            %Schema{
              type: :string,
              description: "Use NEXT the token to get next page of results,
              use PREVIOUS to get the deployments before the token.",
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
              "History of deployment target",
              "application/json",
              @response_schema,
              links: Pagination.token_links(@operation_id)
            )
        })
    }
  end

  def history(conn, _opts) do
    user_id = conn.assigns[:user_id]

    conn
    |> get_resource_id()
    |> case do
      nil ->
        Logger.debug(
          "Error listing history of a deployment target: could not find the deployment target"
        )

        PublicAPI.Util.ToTuple.not_found_error(%{message: "Not found"})
        |> PublicAPI.Util.Response.respond(conn)
        |> Plug.Conn.halt()

      target_id ->
        conn.params
        |> Map.merge(%{
          target_id: target_id,
          cursor_value: conn.params.page_token,
          cursor_type: cursor_type(conn.params),
          user_id: user_id
        })
        |> DTClient.history()
        |> set_response(conn)
    end
  rescue
    error ->
      conn |> handle_error(error, "fetching history")
  end

  defp cursor_type(%{page_token: ""}), do: "FIRST"
  defp cursor_type(%{direction: "NEXT"}), do: "BEFORE"
  defp cursor_type(%{direction: "PREVIOUS"}), do: "AFTER"
end
