defmodule RepositoryHub.GithubAdapter do
  alias RepositoryHub.{
    UserClient,
    ServiceAccountClient,
    RepositoryIntegratorClient,
    GithubClient,
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
        fetch_token_for_github_app(adapter, slug, git_repository.remote_id)

      integration ->
        """
        Unknown integration type: #{inspect(integration)} for #{__MODULE__}
        """
        |> log(level: :error)
        |> error()
    end
  end

  @spec repository_permissions(
          Ecto.UUID.t(),
          %{repo_owner: String.t(), repo_name: String.t()},
          String.t(),
          String.t()
        ) :: Toolkit.tupled_result(map())
  def repository_permissions(user_id, repository, token, no_login_message) do
    UserClient.get_repository_provider_logins(:GITHUB, user_id)
    |> unwrap(fn
      [] ->
        fail_with(:precondition, no_login_message)

      [username | _] ->
        repository
        |> Map.put(:username, username)
        |> GithubClient.repository_permissions(token: token)
    end)
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

  @doc """
  Access a user has to a repository reachable through the GitHub app.

  A service account has no identity on GitHub, so it acts for its owner and the owner's
  access to the repository is what decides. A self-hosted install serves one organization
  behind one app and does not make the distinction, and neither does an install where
  `ENFORCE_SERVICE_ACCOUNT_OWNER` is not yet on.
  """
  def github_app_permissions(
        user,
        github_repository,
        github_token,
        no_login_message \\ "No GitHub account is connected to Semaphore."
      ) do
    if service_account?(user) do
      owner_permissions(user, github_repository, github_token)
    else
      member_permissions(user.user_id, github_repository, github_token, no_login_message)
    end
  end

  defp service_account?(%{user: %{creation_source: :SERVICE_ACCOUNT}}), do: true
  defp service_account?(_user), do: false

  defp owner_permissions(user, github_repository, github_token) do
    if on_prem?() or not enforce_owner?() do
      wrap(%{"admin" => true, "push" => true})
    else
      user
      |> owner_id()
      |> unwrap(
        &member_permissions(
          &1,
          github_repository,
          github_token,
          "The owner of this service account has no GitHub account connected to Semaphore."
        )
      )
    end
  end

  defp owner_id(user) do
    ServiceAccountClient.describe(user.user_id, user.user.org_id)
    |> unwrap(fn
      %{service_account: %{owner_id: owner_id, owner_active: true}} when owner_id != "" ->
        wrap(owner_id)

      _ ->
        fail_with(
          :precondition,
          "This service account has no owner in the organization, so it cannot add repositories. " <>
            "A member of the organization has to be set as its owner first."
        )
    end)
  end

  # The same lookup a person gets, named for whose access is being asked about. Both
  # callers say what to tell somebody with no connected account, so there is no default.
  defp member_permissions(user_id, github_repository, github_token, no_login_message) do
    repository_permissions(
      user_id,
      %{repo_owner: github_repository.owner, repo_name: github_repository.name},
      github_token,
      no_login_message
    )
  end

  defp on_prem?, do: Application.get_env(:repository_hub, :on_prem?, false)

  defp enforce_owner?,
    do: Application.get_env(:repository_hub, :enforce_service_account_owner?, false)

  defp fetch_token_for_github_app(adapter, repository_slug, repository_remote_id) do
    adapter.integration_type
    |> to_integration_type
    |> RepositoryIntegratorClient.get_token(repository_slug, repository_remote_id)
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
