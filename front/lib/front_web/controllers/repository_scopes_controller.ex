defmodule FrontWeb.RepositoryScopesController do
  use FrontWeb, :controller

  alias Front.Models

  plug(FrontWeb.Plugs.OrganizationAuthorization)

  def github_app(conn, _) do
    Watchman.benchmark("scopes.update.duration", fn ->
      choose_repo_path =
        if FeatureProvider.feature_enabled?(:new_project_onboarding, conn.assigns.organization_id) do
          github_choose_repository_path(conn, :index)
        else
          github_choose_repository_path(conn, :choose_repository)
        end

      path = "https://#{org_name(conn)}.#{domain()}#{choose_repo_path}"

      url = "https://id.#{domain()}/oauth/github?redirect_path=#{path}"

      redirect(conn, external: url)
    end)
  end

  def github(conn, %{"access_level" => access_level}) do
    Watchman.benchmark("scopes.update.duration", fn ->
      scope =
        case access_level do
          "public" -> "public_repo,user:email"
          "private" -> "repo,user:email"
          "email" -> "user:email"
          _ -> "repo,user:email"
        end

      choose_repo_path =
        if FeatureProvider.feature_enabled?(:new_project_onboarding, conn.assigns.organization_id) do
          github_legacy_choose_repository_path(conn, :index)
        else
          github_legacy_choose_repository_path(conn, :choose_repository)
        end

      path = "https://#{org_name(conn)}.#{domain()}#{choose_repo_path}"

      url = "https://id.#{domain()}/oauth/github?scope=#{scope}&redirect_path=#{path}"

      redirect(conn, external: url)
    end)
  end

  def bitbucket(conn, _) do
    Watchman.benchmark("scopes.update.duration", fn ->
      choose_repo_path =
        if FeatureProvider.feature_enabled?(:new_project_onboarding, conn.assigns.organization_id) do
          bitbucket_choose_repository_path(conn, :index)
        else
          bitbucket_choose_repository_path(conn, :choose_repository)
        end

      path = "https://#{org_name(conn)}.#{domain()}#{choose_repo_path}"

      url = "https://id.#{domain()}/oauth/bitbucket?redirect_path=#{path}"

      redirect(conn, external: url)
    end)
  end

  def gitlab(conn, _) do
    Watchman.benchmark("scopes.update.duration", fn ->
      choose_repo_path =
        if FeatureProvider.feature_enabled?(:new_project_onboarding, conn.assigns.organization_id) do
          gitlab_choose_repository_path(conn, :index)
        else
          ""
        end

      path = "https://#{org_name(conn)}.#{domain()}#{choose_repo_path}"

      url = "https://id.#{domain()}/oauth/gitlab?redirect_path=#{path}"

      redirect(conn, external: url)
    end)
  end

  defp org_name(conn) do
    organization =
      conn.assigns.organization_id
      |> Models.Organization.find()

    organization.username
  end

  defp domain do
    Application.get_env(:front, :domain)
  end
end
