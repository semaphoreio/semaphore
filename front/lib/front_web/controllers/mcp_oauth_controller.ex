defmodule FrontWeb.McpOAuthController do
  use FrontWeb, :controller

  alias Front.Models.{McpGrant, User}

  plug(FrontWeb.Plugs.CacheControl, :no_cache)
  plug(:put_layout, false)

  def grant_selection(conn, %{"consent_challenge" => challenge_id}) do
    with {:ok, user_id} <- ensure_authenticated_user(conn),
         {:ok, response} <- McpGrant.describe_consent_challenge(challenge_id, user_id) do
      user = User.find(user_id)

      render(conn, "grant_selection.html",
        challenge_id: challenge_id,
        challenge: response.challenge,
        user: user,
        user_id: user_id,
        default_org_grants: index_org_grants(response.default_selection),
        default_project_grants: index_project_grants(response.default_selection),
        available_organizations: List.wrap(response.available_organizations),
        available_projects: List.wrap(response.available_projects),
        found_existing_grant: response.found_existing_grant || false
      )
    else
      {:error, :unauthorized} ->
        send_plain_error(conn, 401, "User not authenticated")

      {:error, :not_found} ->
        send_plain_error(conn, 404, "Consent challenge not found or expired")

      {:error, {:invalid_argument, message}} ->
        send_plain_error(conn, 400, message)

      {:error, {:failed_precondition, message}} ->
        send_plain_error(conn, 422, message)

      {:error, {:rpc_error, _message}} ->
        send_plain_error(conn, 502, "Failed to load consent challenge")
    end
  end

  def grant_selection(conn, _params) do
    send_plain_error(conn, 400, "Missing consent_challenge parameter")
  end

  def submit_grant_selection(conn, %{"consent_challenge" => challenge_id} = params) do
    with {:ok, user_id} <- ensure_authenticated_user(conn) do
      case decision(params["decision"]) do
        :deny ->
          deny_consent(conn, challenge_id, user_id)

        :approve ->
          approve_consent(conn, challenge_id, user_id, params)
      end
    else
      {:error, :unauthorized} ->
        send_plain_error(conn, 401, "User not authenticated")
    end
  end

  def submit_grant_selection(conn, _params) do
    send_plain_error(conn, 400, "Missing consent_challenge parameter")
  end

  defp approve_consent(conn, challenge_id, user_id, params) do
    with {:ok, response} <- McpGrant.describe_consent_challenge(challenge_id, user_id),
         selection <- sanitize_selection(params["selection"], response),
         {:ok, approve_response} <-
           McpGrant.approve_consent_challenge(challenge_id, user_id, selection) do
      redirect_to_client(conn, approve_response.redirect_url)
    else
      {:error, :not_found} ->
        send_plain_error(conn, 404, "Consent challenge not found or expired")

      {:error, {:invalid_argument, message}} ->
        send_plain_error(conn, 400, message)

      {:error, {:failed_precondition, message}} ->
        send_plain_error(conn, 422, message)

      {:error, {:rpc_error, _message}} ->
        send_plain_error(conn, 502, "Failed to approve consent challenge")
    end
  end

  defp deny_consent(conn, challenge_id, user_id) do
    with {:ok, deny_response} <- McpGrant.deny_consent_challenge(challenge_id, user_id) do
      redirect_to_client(conn, deny_response.redirect_url)
    else
      {:error, :not_found} ->
        send_plain_error(conn, 404, "Consent challenge not found or expired")

      {:error, {:invalid_argument, message}} ->
        send_plain_error(conn, 400, message)

      {:error, {:failed_precondition, message}} ->
        send_plain_error(conn, 422, message)

      {:error, {:rpc_error, _message}} ->
        send_plain_error(conn, 502, "Failed to deny consent challenge")
    end
  end

  defp ensure_authenticated_user(conn) do
    case conn.assigns[:user_id] do
      user_id when is_binary(user_id) and user_id != "" -> {:ok, user_id}
      _ -> {:error, :unauthorized}
    end
  end

  defp decision("approve"), do: :approve
  defp decision(_), do: :deny

  defp redirect_to_client(conn, redirect_url) do
    if valid_client_redirect_url?(redirect_url) do
      redirect(conn, external: redirect_url)
    else
      send_plain_error(conn, 502, "Invalid redirect URL returned from authorization server")
    end
  end

  defp valid_client_redirect_url?(redirect_url) when is_binary(redirect_url) do
    case URI.parse(redirect_url) do
      %URI{scheme: "https", host: host} when is_binary(host) and host != "" -> true
      %URI{scheme: "http", host: host} when host in ["localhost", "127.0.0.1", "::1"] -> true
      _ -> false
    end
  end

  defp valid_client_redirect_url?(_), do: false

  defp index_org_grants(nil), do: %{}

  defp index_org_grants(default_selection) do
    default_selection.org_grants
    |> List.wrap()
    |> Enum.reduce(%{}, fn org_grant, acc ->
      Map.put(acc, org_grant.org_id, org_grant)
    end)
  end

  defp index_project_grants(nil), do: %{}

  defp index_project_grants(default_selection) do
    default_selection.project_grants
    |> List.wrap()
    |> Enum.reduce(%{}, fn project_grant, acc ->
      Map.put(acc, project_grant.project_id, project_grant)
    end)
  end

  defp sanitize_selection(selection_params, response) do
    selection_params = if is_map(selection_params), do: selection_params, else: %{}

    available_organizations =
      response.available_organizations
      |> List.wrap()
      |> Enum.reduce(%{}, fn org, acc -> Map.put(acc, org.org_id, org) end)

    org_grants =
      selection_params
      |> Map.get("org_grants", %{})
      |> sanitize_org_grants(available_organizations)

    available_projects =
      response.available_projects
      |> List.wrap()
      |> Enum.reduce(%{}, fn project, acc -> Map.put(acc, project.project_id, project) end)

    project_grants =
      selection_params
      |> Map.get("project_grants", %{})
      |> sanitize_project_grants(available_projects)

    %{
      tool_scopes: default_tool_scopes(response.default_selection),
      org_grants: org_grants,
      project_grants: project_grants
    }
  end

  defp sanitize_org_grants(org_params, available_organizations) when is_map(org_params) do
    org_params
    |> Enum.reduce([], fn {org_id, requested}, acc ->
      case Map.get(available_organizations, org_id) do
        nil ->
          acc

        available_org ->
          can_view = checked?(requested, "can_view") and available_org.can_view

          can_run_workflows =
            checked?(requested, "can_run_workflows") and available_org.can_run_workflows

          if can_view or can_run_workflows do
            [
              %{
                org_id: org_id,
                can_view: can_view,
                can_run_workflows: can_run_workflows
              }
              | acc
            ]
          else
            acc
          end
      end
    end)
    |> Enum.reverse()
  end

  defp sanitize_org_grants(_org_params, _available_organizations), do: []

  defp sanitize_project_grants(project_params, available_projects) when is_map(project_params) do
    project_params
    |> Enum.reduce([], fn {project_id, requested}, acc ->
      case Map.get(available_projects, project_id) do
        nil ->
          acc

        available_project ->
          can_view = checked?(requested, "can_view") and available_project.can_view

          can_run_workflows =
            checked?(requested, "can_run_workflows") and available_project.can_run_workflows

          can_view_logs = checked?(requested, "can_view_logs") and available_project.can_view_logs

          if can_view or can_run_workflows or can_view_logs do
            [
              %{
                project_id: project_id,
                org_id: available_project.org_id,
                can_view: can_view,
                can_run_workflows: can_run_workflows,
                can_view_logs: can_view_logs
              }
              | acc
            ]
          else
            acc
          end
      end
    end)
    |> Enum.reverse()
  end

  defp sanitize_project_grants(_project_params, _available_projects), do: []

  defp checked?(requested, key) when is_map(requested) do
    value = Map.get(requested, key)
    value in ["true", "on", "1", true, 1]
  end

  defp checked?(_requested, _key), do: false

  defp default_tool_scopes(nil), do: []
  defp default_tool_scopes(default_selection), do: List.wrap(default_selection.tool_scopes)

  defp send_plain_error(conn, status, message) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, message)
  end
end
