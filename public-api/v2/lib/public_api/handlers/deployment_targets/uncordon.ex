defmodule PublicAPI.Handlers.DeploymentTargets.Uncordon do
  @moduledoc """
  Plug Activates a deployment target.
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

  @operation_id "DeploymentTargets.Activate"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.DeploymentTargets.CordonResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.deployment_targets.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["activate", "deployment_targets"])

  plug(PublicAPI.Handlers.DeploymentTargets.Plugs.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:activate)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["DeploymentTargets"],
      summary: "Activate a project deployment targets",
      description: "Activate a deployment target for the project.",
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
          :id_or_name,
          :path,
          %Schema{
            type: :string,
            description: "Id or name of the deployment target"
          },
          "Id or name of the deployment target",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Activated deployment target",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def activate(conn, _opts) do
    conn
    |> get_resource_id()
    |> case do
      nil ->
        Logger.debug("Error activating a deployment target: could not find the deployment target")

        PublicAPI.Util.ToTuple.not_found_error(%{message: "Not found"})
        |> PublicAPI.Util.Response.respond(conn)
        |> Plug.Conn.halt()

      id ->
        %{
          target_id: id,
          cordon: false
        }
        |> DTClient.cordon()
        |> set_response(conn)
    end
  rescue
    error ->
      conn |> handle_error(error, "activating")
  end
end
