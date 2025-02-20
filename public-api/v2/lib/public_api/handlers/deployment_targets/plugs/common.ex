defmodule PublicAPI.Handlers.DeploymentTargets.Plugs.Common do
  @moduledoc """
  Utility functions needed to handle deployment targets operations.
  """

  use Plug.Builder
  alias InternalClients.DeploymentTargets, as: DeploymentsClient

  @sensitive_param_fields ~w(key old_env_vars old_files old_target)
  @plans_docs_link "https://semaphoreci.com/pricing"

  def remove_sensitive_params(conn = %{params: params}, _opts) do
    conn |> Map.put(:params, params |> Map.drop(@sensitive_param_fields))
  end

  # Feature flag checking for deployment targets

  def has_deployment_targets_enabled(
        conn = %{
          params: %{"deployment_target" => %{"spec" => %{"subject_rules" => nil}}}
        },
        opts
      ),
      do: has_feature_enabled(conn, opts, "deployment_targets")

  def has_deployment_targets_enabled(
        conn = %{
          params: %{"deployment_target" => %{"spec" => %{"subject_rules" => %{"any" => true}}}}
        },
        opts
      ),
      do: has_feature_enabled(conn, opts, "deployment_targets")

  def has_deployment_targets_enabled(
        conn = %{
          params: %{"deployment_target" => %{"spec" => %{"subject_rules" => _subject_rules}}}
        },
        opts
      ),
      do: has_feature_enabled(conn, opts, "advanced_deployment_targets")

  def has_deployment_targets_enabled(conn, opts),
    do: has_feature_enabled(conn, opts, "deployment_targets")

  defp has_feature_enabled(conn, _opts, feature) do
    with org_id <- Plug.Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0),
         true <- FeatureProvider.feature_enabled?(feature, param: org_id) do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> resp(
          404,
          %{
            message:
              "The #{feature_name(feature)} feature is not enabled for your organization. See more details here: #{@plans_docs_link}"
          }
          |> Jason.encode!()
        )
        |> halt
    end
  end

  defp feature_name(feature), do: feature |> to_string |> String.replace("_", " ")

  # Project id by deployment target id

  def get_project_id(conn, opts), do: get_project_id_(conn, opts)

  defp get_project_id_(conn = %{params: %{project_id: _project_id}}, _opts), do: conn

  defp get_project_id_(conn, _opts) do
    case retrieve_project_id(conn, conn.params) do
      {:ok, project_id} ->
        if Map.has_key?(conn.params, "project_id") and project_id !== conn.params["project_id"] do
        else
          conn |> Map.put(:params, Map.put(conn.params, "project_id", project_id))
        end

      {:error, error} ->
        error |> PublicAPI.Util.Response.respond(conn) |> halt()
    end
  end

  defp retrieve_project_id(conn, %{"target_id" => target_id}),
    do: retrieve_project_id(conn, target_id)

  defp retrieve_project_id(_conn, %{"project_id" => project_id}), do: {:ok, project_id}

  defp retrieve_project_id(conn, %{"id" => target_id}), do: retrieve_project_id(conn, target_id)

  defp retrieve_project_id(conn, target_id)
       when is_binary(target_id) and byte_size(target_id) > 0 do
    DeploymentsClient.describe(%{"target_id" => target_id})
    |> process_response(conn)
  end

  defp process_response({:ok, target}, _conn), do: {:ok, target.project_id}

  defp process_response(error, _conn), do: {:error, error}
end
