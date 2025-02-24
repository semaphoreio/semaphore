defmodule FrontWeb.MeView do
  use FrontWeb, :view

  def name(user) do
    case String.split(user.name, " ", trim: true) do
      [] -> user.github_login
      [fname, _lname] -> fname
      [name] -> name
      [fname | _tail] -> fname
    end
  end

  def home_page(organization) do
    "https://#{organization.username}.#{Application.get_env(:front, :domain)}"
  end

  def org_url(organization) do
    "#{organization.username}.#{Application.get_env(:front, :domain)}"
  end

  def github_choose_repository_org_url(conn, organization) do
    subdomain = organization.username
    domain = Application.get_env(:front, :domain)

    path =
      if FeatureProvider.feature_enabled?(:new_project_onboarding, param: organization.id) do
        github_choose_repository_path(conn, :index)
      else
        github_choose_repository_path(conn, :choose_repository)
      end

    "//#{subdomain}.#{domain}#{path}"
  end

  def username_already_taken?(errors) do
    specific_error_on_field?(errors, "username", "taken")
  end

  def other_username_error?(errors) do
    if errors && errors["username"] do
      !(List.first(errors["username"]) =~ "taken")
    end
  end

  def name_missing?(errors) do
    specific_error_on_field?(errors, "name", "empty")
  end

  defp specific_error_on_field?(errors, field, word) do
    if errors && errors[field] do
      List.first(errors[field]) =~ word
    end
  end
end
