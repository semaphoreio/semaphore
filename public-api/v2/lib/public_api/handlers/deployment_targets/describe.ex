defmodule PublicAPI.Handlers.DeploymentTargets.Describe do
  @moduledoc """
  Plug Describes a deployment target.
  """

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

  @operation_id "DeploymentTargets.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.DeploymentTargets.DeploymentTarget

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.deployment_targets.view"]
  )

  plug(PublicAPI.Plugs.SecretsKey)

  plug(PublicAPI.Plugs.Metrics, tags: ["describe", "deployment_targets"])
  plug(PublicAPI.Handlers.DeploymentTargets.Plugs.Loader)
  plug(:describe)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["DeploymentTargets"],
      summary: "Describe a project deployment targets",
      description: "Describe a deployment target for the project.",
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
          :with_credentials,
          :query,
          %Schema{
            type: :boolean,
            description: "If true, fetches the credentials associated with the deployment target",
            default: false
          },
          "If true, fetches the secret associated with the deployment target",
          required: false
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Described deployment target",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def describe(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    fetch? = conn.params.with_credentials

    secret_aditional_params = %{
      user_id: user_id,
      org_id: org_id,
      project_id: conn.assigns[:project_id]
    }

    conn
    |> get_resource()
    |> maybe_fetch_secret(fetch?, secret_aditional_params)
    |> set_response(conn)
  rescue
    error ->
      conn
      |> handle_error(error, "describing")
  end

  def maybe_fetch_secret({:ok, target}, _fetch? = false, _params), do: {:ok, target}

  def maybe_fetch_secret({:ok, target}, _fetch? = true, params) do
    %{
      deployment_target_id: target.metadata.id,
      organization_id: params.org_id,
      user_id: params.user_id,
      project_id: params.project_id,
      secret_level: :DEPLOYMENT_TARGET
    }
    |> InternalClients.Secrets.describe()
    |> case do
      {:ok, secret} ->
        target_spec =
          target.spec
          |> Map.put(:env_vars, secret.spec.data.env_vars)
          |> Map.put(:files, secret.spec.data.files)

        target = Map.put(target, :spec, target_spec)
        {:ok, target}

      {:error, _} ->
        Logger.error(
          "Failed to fetch secret for deployment target: #{inspect(target.metadata.id)}"
        )

        {:ok, target}
    end
  end

  def maybe_fetch_secret(resp, _fetch?, _params), do: resp
end
