defmodule RepositoryHub.GitProviderValidator do
  alias RepositoryHub.Validator

  def validate_provider(provider, _opts \\ []) do
    provider
    |> Validator.validate(
      any: [
        eq: "bitbucket",
        eq: "github",
        eq: "git"
      ]
    )
  end

  def validate_integration_type(integration_type, _opts \\ []) do
    integration_type
    |> Validator.validate(
      any: [
        eq: "bitbucket",
        eq: "github_app",
        eq: "github_oauth_token",
        eq: "git"
      ]
    )
  end
end
