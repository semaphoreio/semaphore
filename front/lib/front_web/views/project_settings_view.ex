defmodule FrontWeb.ProjectSettingsView do
  use FrontWeb, :view

  def deploy_key_config(conn) do
    regenerate_url =
      if conn.assigns.permissions["project.repository_info.manage"] do
        project_settings_path(conn, :regenerate_deploy_key, conn.assigns.project.name)
      else
        ""
      end

    %{
      public_key: get_in(conn.assigns, [:deploy_key, :public_key]) || "",
      title: get_in(conn.assigns, [:deploy_key, :title]) || "",
      fingerprint: get_in(conn.assigns, [:deploy_key, :fingerprint]) || "",
      created_at: get_in(conn.assigns, [:deploy_key, :created_at]) || "",
      message: get_in(conn.assigns, [:deploy_key_message]) || "",
      regenerate_url: regenerate_url
    }
  end

  def webhook_config(conn) do
    regenerate_url =
      if conn.assigns.permissions["project.repository_info.manage"] do
        project_onboarding_path(conn, :regenerate_webhook_secret, conn.assigns.project.name)
      else
        ""
      end

    connected = Map.get(conn.assigns.project, :repo_connected, false)

    %{
      hook_url: get_in(conn.assigns, [:hook, :url]) || "",
      connected: connected,
      message: get_in(conn.assigns, [:hook_message]) || "",
      regenerate_url: regenerate_url
    }
  end

  def project_owner_box_class(token) do
    if token.valid do
      "bg-washed-yellow"
    else
      "bg-washed-red"
    end
  end

  def user_github_profile_link(login) do
    "https://github.com/#{login}"
  end

  ### Project deletion form

  def compose_feedback_placeholder(timestamp) do
    if !is_nil(timestamp) and in_last_7_days?(timestamp) do
      "Is there a problem we can help you with? (required)"
    else
      "Any additional comments? (optional)"
    end
  end

  defp in_last_7_days?(timestamp) do
    Front.ProjectSettings.DeletionValidator.in_last_7_days?(timestamp)
  end
end
