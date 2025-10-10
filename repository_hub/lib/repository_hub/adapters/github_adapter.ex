defmodule RepositoryHub.GithubAdapter do
  alias RepositoryHub.{
    UserClient,
    RepositoryIntegratorClient,
    Model,
    Toolkit,
    GithubAdapter,
    UniversalAdapter
  }

  import Toolkit

  @type t :: %GithubAdapter{}
  defstruct [:integration_type, :name, :short_name]

  @doc """
  Creates a new GithubAdapter

  # Examples

    iex> RepositoryHub.GithubAdapter.new("github_oauth_token")
    %RepositoryHub.GithubAdapter{integration_type: "github_oauth_token", name: "Github[github_oauth_token]", short_name: "gho"}

    iex> RepositoryHub.GithubAdapter.new("github_app")
    %RepositoryHub.GithubAdapter{integration_type: "github_app", name: "Github[github_app]", short_name: "gha"}

    iex> RepositoryHub.GithubAdapter.new("GITHUB_APP")
    %RepositoryHub.GithubAdapter{integration_type: "github_app", name: "Github[github_app]", short_name: "gha"}

  """
  def new(integration_type) do
    integration_type = String.downcase(integration_type)

    short_name =
      integration_type
      |> case do
        "github_app" ->
          "gha"

        "github_oauth_token" ->
          "gho"

        _ ->
          "inv"
      end

    %GithubAdapter{integration_type: integration_type, name: "Github[#{integration_type}]", short_name: short_name}
  end

  def integration_types, do: ["github_oauth_token", "github_app"]

  def token(adapter, user_id, git_repository) do
    slug = Model.GitRepository.slug(git_repository)

    adapter.integration_type
    |> case do
      "github_oauth_token" ->
        fetch_token_by_user_id(adapter, user_id)

      "github_app" ->
        fetch_token_by_slug(adapter, slug)

      integration ->
        """
        Unknown integration type: #{inspect(integration)} for #{__MODULE__}
        """
        |> log(level: :error)
        |> error()
    end
  end

  def fetch_token_by_user_id(adapter, user_id) do
    with {:ok, user} <- UserClient.describe(user_id),
         :ok <- validate_not_service_account(user, "GitHub") do
      adapter.integration_type
      |> UserClient.get_repository_token(user_id)
    end
  end

  defp validate_not_service_account(%{user: %{creation_source: :SERVICE_ACCOUNT}}, provider_name) do
    error("Service accounts cannot use #{provider_name} OAuth tokens. Please use the appropriate integration type.")
  end

  defp validate_not_service_account(_user, _provider_name), do: :ok

  def fetch_token_by_slug(adapter, slug) do
    adapter.integration_type
    |> to_integration_type
    |> RepositoryIntegratorClient.get_token(slug)
  end

  @spec to_integration_type(binary) :: 0 | 1 | 2
  defp to_integration_type(value) do
    value
    |> String.upcase()
    |> String.to_atom()
  end

  def context(adapter, repository_id, stream \\ nil) do
    with {:ok, context} <- UniversalAdapter.context(repository_id, stream),
         {:ok, github_token} <- GithubAdapter.token(adapter, context.project.metadata.owner_id, context.git_repository) do
      context
      |> Map.put(:github_token, github_token)
      |> wrap()
    end
  end
end
