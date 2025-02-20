defmodule Guard.InstanceConfig.BitbucketApp do
  @permissions %{
    "Accounts" => "read",
    "Issues" => "read",
    "Workspace membership" => "read",
    "Projects" => "read",
    "Webhooks" => "read and write",
    "Repositories" => "admin",
    "Pull requests" => "write"
  }

  def redirect_urls do
    base_domain = Application.get_env(:guard, :base_domain)

    [
      "https://id.#{base_domain}/oauth/bitbucket/callback"
    ]
  end

  @doc """
  Returns default permissions required for Bitbucket integration.
  """
  def permissions do
    @permissions
  end
end
