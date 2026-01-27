defmodule Guard.InstanceConfig.GithubApp do
  require Logger

  def manifest(org_username \\ "", is_public \\ false) do
    default_rand_name =
      "#{org_username}-" <>
        for(_ <- 1..10, into: "", do: <<Enum.random('0123456789abcdef')>>)

    base_domain = Application.get_env(:guard, :base_domain)

    url = "https://id.#{base_domain}"

    callback_urls = [
      "https://id.#{base_domain}/auth/github/callback",
      "https://id.#{base_domain}/oauth/github/callback"
    ]

    setup_url = "https://me.#{base_domain}/github_app_installation"
    webhook_url = "https://hooks.#{base_domain}/github"
    redirect_url = Application.get_env(:guard, :github_app_redirect_url)

    %{
      name: default_rand_name,
      description: "Semaphore CI/CD self hosted application",
      url: url,
      callback_urls: callback_urls,
      setup_url: setup_url,
      hook_attributes: %{url: webhook_url, active: true},
      public: is_public,
      redirect_url: redirect_url,
      default_events: [
        "create",
        "delete",
        "membership",
        "organization",
        "repository",
        "team"
      ],
      default_permissions: %{
        administration: "write",
        checks: "write",
        contents: "write",
        issues: "read",
        members: "read",
        metadata: "read",
        organization_hooks: "write",
        pull_requests: "read",
        repository_hooks: "write",
        statuses: "write",
        emails: "read"
      }
    }
  end

  def fetch(code) do
    Guard.Api.GithubApp.fetch(code)
  rescue
    e ->
      Logger.error("Failed to fetch Github App info: #{inspect(e)}")
      {:error, "Failed to fetch Github App info"}
  end

  def state_check(gh_app_conf) do
    Guard.Api.GithubApp.get(gh_app_conf)
    |> case do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end
end
