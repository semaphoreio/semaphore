defmodule FrontWeb.MeController do
  use FrontWeb, :controller

  alias Front.Models

  plug(:put_layout, "me.html")
  plug(FrontWeb.Plugs.CacheControl, :no_cache)

  def show(conn, params) do
    Watchman.benchmark("me.show.duration", fn ->
      tracing_headers = conn.assigns.tracing_headers
      user_id = conn.assigns.user_id

      organizations = Models.Organization.list(user_id)
      user = Models.User.find(user_id, tracing_headers)

      signup = params["signup"]
      notice = extract_notice(params)

      case Enum.count(organizations) do
        0 ->
          conn
          |> redirect(to: organization_onboarding_path(conn, :new))

        1 ->
          org = List.first(organizations)
          redirect_to_org(conn, org)

        _ ->
          render_me_page(conn, user, organizations, signup, notice)
      end
    end)
  end

  def github_app_installation(conn, %{"state" => state}) do
    Watchman.benchmark("me.github_app_installation.duration", fn ->
      case extract_state(state) do
        nil ->
          conn
          |> redirect(to: me_path(conn, :github_app_installation))

        {project, org} ->
          redirect_to_org_project(conn, org, project)

        org ->
          redirect_to_org_choose_repo(conn, org)
      end
    end)
  end

  def github_app_installation(conn, _params) do
    Watchman.benchmark("me.github_app_installation.duration", fn ->
      user_id = conn.assigns.user_id

      organizations = Models.Organization.list(user_id)
      user = Models.User.find(user_id)

      case Enum.count(organizations) do
        0 ->
          conn
          |> redirect(to: me_path(conn, :show))

        1 ->
          org = List.first(organizations)
          redirect_to_org_choose_repo(conn, org)

        _ ->
          render_orgs_list(conn, user, organizations)
      end
    end)
  end

  def permissions_initialized(conn, params) do
    user_id = params["user_id"]
    org_id = params["org_id"]

    is_member = Front.RBAC.Members.is_org_member?(org_id, user_id)

    response = %{
      permissions_setup: is_member
    }

    conn |> json(response)
  end

  defp extract_state(state) when not is_binary(state), do: nil

  defp extract_state(state) do
    cond do
      String.starts_with?(state, "o_") ->
        extract_state(:org, String.slice(state, 2, 36))

      String.starts_with?(state, "p_") ->
        extract_state(:project, String.slice(state, 2, 36))

      true ->
        extract_state(:encoded, state)
    end
  end

  defp extract_state(:org, org_id) do
    Models.Organization.find(org_id)
  end

  defp extract_state(:project, project_id) do
    case Models.Project.find_by_id(project_id) do
      nil ->
        nil

      project ->
        {project, Models.Organization.find(project.organization_id)}
    end
  end

  defp extract_state(:encoded, state) do
    with {:ok, decoded_json} <- Base.decode64(state, padding: false),
         {:ok, decoded} <- Poison.decode(decoded_json),
         org_id when org_id != nil <- Map.get(decoded, "org_id") do
      extract_state(:org, org_id)
    else
      _ -> nil
    end
  end

  defp redirect_to_org(conn, org) do
    subdomain = org.username
    domain = Application.get_env(:front, :domain)

    conn
    |> redirect(external: "//#{subdomain}.#{domain}")
  end

  defp redirect_to_org_choose_repo(conn, org) do
    subdomain = org.username
    domain = Application.get_env(:front, :domain)

    path =
      if FeatureProvider.feature_enabled?(:new_project_onboarding, org.id) do
        github_choose_repository_path(conn, :index)
      else
        github_choose_repository_path(conn, :choose_repository)
      end

    conn
    |> redirect(external: "//#{subdomain}.#{domain}#{path}")
  end

  defp redirect_to_org_project(conn, org, project) do
    subdomain = org.username
    domain = Application.get_env(:front, :domain)
    path = project_settings_path(conn, :repository, project.name)

    conn
    |> redirect(external: "//#{subdomain}.#{domain}#{path}")
  end

  defp render_orgs_list(conn, user, orgs) do
    render(
      conn,
      "github_app_installation.html",
      title: "Welcome back to Semaphore.",
      signup: false,
      user: user,
      organizations: orgs
    )
  end

  defp extract_notice(params) do
    if params["notice"] do
      Poison.decode!(params["notice"])
    end
  end

  defp render_me_page(conn, user, organizations, signup, notice) do
    render(
      conn,
      "show.html",
      title: "Welcome back to Semaphore.",
      user: user,
      organizations: organizations,
      signup: signup,
      notice: notice
    )
  end
end
