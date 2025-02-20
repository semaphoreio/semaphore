defmodule FrontWeb.ProjectSettingsView do
  use FrontWeb, :view

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
