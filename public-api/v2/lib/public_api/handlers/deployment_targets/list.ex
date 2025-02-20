defmodule PublicAPI.Handlers.DeploymentTargets.List do
  @moduledoc false
  require Logger

  alias InternalClients.DeploymentTargets, as: DTClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  plug(PublicAPI.Plugs.FeatureFlag, feature: "deployment_targets")

  @operation_id "DeploymentTargets.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.DeploymentTargets.ListResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.deployment_targets.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["list", "deployment_targets"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["DeploymentTargets"],
      summary: "List project deployment targets",
      description: "List of deployment targets for the project.",
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
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of deployment targets",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def list(conn, _opts) do
    user_id = conn.assigns[:user_id]

    Map.merge(conn.params, %{
      user_id: user_id,
      project_id: conn.assigns[:project_id]
    })
    |> DTClient.list()
    |> set_response(conn)
  end
end
