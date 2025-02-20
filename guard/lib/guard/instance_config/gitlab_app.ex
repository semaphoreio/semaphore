defmodule Guard.InstanceConfig.GitlabApp do
  @permissions %{
    "api" => "true",
    "read_api" => "true",
    "read_user" => "true",
    "read_repository" => "true",
    "write_repository" => "true",
    "openid" => "true"
  }

  @doc """
  Returns a list of allowed redirect URLs for OAuth callbacks.
  """
  def redirect_urls do
    base_domain = Application.get_env(:guard, :base_domain)

    [
      "https://id.#{base_domain}/oauth/gitlab/callback",
      "https://id.#{base_domain}/auth/gitlab/callback"
    ]
  end

  @doc """
  Returns a map of GitLab permissions.
  """
  def permissions do
    @permissions
  end
end
