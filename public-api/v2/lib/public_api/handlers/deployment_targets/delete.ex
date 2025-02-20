defmodule PublicAPI.Handlers.DeploymentTargets.Delete do
  @moduledoc """
  Plug Deletes a deployment target.
  """

  alias InternalClients.DeploymentTargets, as: DTClient
  alias PublicAPI.Schemas

  import PublicAPI.Handlers.DeploymentTargets.Plugs.Common,
    only: [remove_sensitive_params: 2]

  import PublicAPI.Handlers.DeploymentTargets.Util.ErrorHandler

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  require Logger

  plug(:remove_sensitive_params)
  plug(PublicAPI.Plugs.FeatureFlag, feature: "deployment_targets")

  @operation_id "DeploymentTargets.Delete"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.DeploymentTargets.DeleteResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.deployment_targets.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["delete", "deployment_targets"])
  plug(PublicAPI.Handlers.DeploymentTargets.Plugs.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["DeploymentTargets"],
      summary: "Delete a project deployment targets",
      description: "Delete a deployment target for the project.",
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
        ),
        Operation.parameter(
          :unique_token,
          :query,
          %Schema{
            type: :string,
            description: "Idempotency token"
          },
          "Idempotency token for the delete operation",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "ID of the deleted deployment target",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def delete(conn, _opts) do
    user_id = conn.assigns[:user_id]

    id = conn |> get_resource_id()

    %{
      unique_token: conn.params.unique_token,
      user_id: user_id,
      target_id: id
    }
    |> DTClient.delete()
    |> set_response(conn)
  rescue
    error ->
      conn |> handle_error(error, "deleting")
  end
end
