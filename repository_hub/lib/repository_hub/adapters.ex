defmodule RepositoryHub.Adapters do
  import RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias InternalApi.Repository.{
    DescribeRequest,
    DescribeManyRequest,
    ListRequest,
    CreateRequest,
    DeleteRequest,
    GetSshKeyRequest,
    GetFileRequest,
    GetFilesRequest,
    GetChangedFilePathsRequest,
    CommitRequest,
    ListCollaboratorsRequest,
    CreateBuildStatusRequest,
    ClearExternalDataRequest,
    ListAccessibleRepositoriesRequest,
    ForkRequest,
    CheckDeployKeyRequest,
    CheckWebhookRequest,
    RegenerateDeployKeyRequest,
    RegenerateWebhookRequest,
    UpdateRequest,
    DescribeRemoteRepositoryRequest,
    DescribeRevisionRequest,
    VerifyWebhookSignatureRequest
  }

  alias RepositoryHub.Model

  alias RepositoryHub.{GithubAdapter, BitbucketAdapter, UniversalAdapter, GitAdapter, GitlabAdapter}

  @type adapter() ::
          GithubAdapter.t() | BitbucketAdapter.t() | UniversalAdapter.t() | GitAdapter.t() | GitlabAdapter.t()

  @doc ~S"""
  Creates a new github repository adapter

  ## Examples

      iex> RepositoryHub.Adapters.github_app()
      %RepositoryHub.GithubAdapter{integration_type: "github_app", name: "Github[github_app]", short_name: "gha"}

  """
  def github_app do
    GithubAdapter.new("github_app")
  end

  @doc ~S"""
  Creates a new github repository adapter

  ## Examples

      iex> RepositoryHub.Adapters.github_oauth()
      %RepositoryHub.GithubAdapter{integration_type: "github_oauth_token", name: "Github[github_oauth_token]", short_name: "gho"}

  """
  def github_oauth do
    GithubAdapter.new("github_oauth_token")
  end

  @doc ~S"""
  Creates a new bitbucket repository adapter

  ## Examples

      iex> RepositoryHub.Adapters.bitbucket()
      %RepositoryHub.BitbucketAdapter{integration_type: "bitbucket", name: "Bitbucket", short_name: "bbo"}

  """
  def bitbucket do
    BitbucketAdapter.new("bitbucket")
  end

  @doc ~S"""
  Creates a new generic_git repository adapter

  ## Examples

      iex> RepositoryHub.Adapters.git()
      %RepositoryHub.GitAdapter{integration_type: "git", name: "Git", short_name: "git"}

  """
  def git do
    GitAdapter.new("git")
  end

  @doc ~S"""
  Creates a new gitlab repository adapter

  ## Examples

      iex> RepositoryHub.Adapters.gitlab()
      %RepositoryHub.GitlabAdapter{integration_type: "gitlab", name: "Gitlab", short_name: "gitlab"}

  """
  def gitlab do
    GitlabAdapter.new("gitlab")
  end

  @doc ~S"""
  Creates a new universal repository adapter

  ## Examples

      iex> RepositoryHub.Adapters.universal()
      %RepositoryHub.UniversalAdapter{name: "Universal", short_name: "uni"}

  """
  def universal do
    UniversalAdapter.new()
  end

  @spec pick(struct()) :: {:ok, adapter()} | {:error, any()}
  # credo:disable-for-next-line
  def pick(request) do
    request.__struct__
    |> case do
      DescribeRequest -> universal() |> wrap()
      DescribeManyRequest -> universal() |> wrap()
      VerifyWebhookSignatureRequest -> universal() |> wrap()
      ListRequest -> universal() |> wrap()
      CreateRequest -> from_integration_type(request)
      DeleteRequest -> from_repository_id(request)
      ClearExternalDataRequest -> from_repository_id(request)
      GetSshKeyRequest -> universal() |> wrap()
      GetFileRequest -> from_repository_id(request)
      GetFilesRequest -> from_repository_id(request)
      GetChangedFilePathsRequest -> from_repository_id(request)
      CommitRequest -> from_repository_id(request)
      ListCollaboratorsRequest -> from_repository_id(request)
      CreateBuildStatusRequest -> from_repository_id(request)
      ListAccessibleRepositoriesRequest -> from_integration_type(request)
      CheckDeployKeyRequest -> from_repository_id(request)
      CheckWebhookRequest -> from_repository_id(request)
      RegenerateDeployKeyRequest -> from_repository_id(request)
      RegenerateWebhookRequest -> from_repository_id(request)
      UpdateRequest -> from_repository_id(request)
      DescribeRemoteRepositoryRequest -> from_integration_type(request)
      DescribeRevisionRequest -> from_repository_id(request)
      ForkRequest -> from_integration_type(request)
      _ -> error("Can't find adapter for request #{request}")
    end
  end

  @spec pick!(struct()) :: adapter()
  def pick!(request) do
    {:ok, adapter} = pick(request)
    adapter
  end

  def from_repository_id(request) do
    request
    |> Validator.validate(
      chain: [
        {:from!, :repository_id},
        :is_uuid,
        error_message: "is not valid repository id"
      ]
    )
    |> unwrap(&Model.RepositoryQuery.get_by_id(&1.repository_id))
    |> unwrap(fn repository ->
      repository.integration_type
      |> case do
        "github_oauth_token" -> github_oauth()
        "github_app" -> github_app()
        "bitbucket" -> bitbucket()
        "git" -> git()
        "gitlab" -> gitlab()
        integration_type -> error("Unknown integration type #{integration_type}")
      end
      |> wrap()
    end)
  end

  @doc """
  Fetches adapter based on git provider.

  ## Examples:

    iex> from_integration_type(%{integration_type: :GITHUB_OAUTH_TOKEN})
    {:ok, %RepositoryHub.GithubAdapter{integration_type: "github_oauth_token", name: "Github[github_oauth_token]", short_name: "gho"}}
    iex> from_integration_type(%{integration_type: :GITHUB_APP})
    {:ok, %RepositoryHub.GithubAdapter{integration_type: "github_app", name: "Github[github_app]", short_name: "gha"}}
    iex> from_integration_type(%{integration_type: :BITBUCKET})
    {:ok, %RepositoryHub.BitbucketAdapter{integration_type: "bitbucket", name: "Bitbucket", short_name: "bbo"}}
    iex> from_integration_type(%{integration_type: :GIT})
    {:ok, %RepositoryHub.GitAdapter{integration_type: "git", name: "Git", short_name: "git"}}

  """
  def from_integration_type(request) do
    request.integration_type
    |> RepositoryHub.Validator.validate([:is_integration_type])
    |> case do
      {:ok, :GITHUB_APP} -> github_app()
      {:ok, :GITHUB_OAUTH_TOKEN} -> github_oauth()
      {:ok, :BITBUCKET} -> bitbucket()
      {:ok, :GIT} -> git()
      {:ok, :GITLAB} -> gitlab()
      validation -> error("No adapter for git provider #{request.integration_type}, validation: #{inspect(validation)}")
    end
    |> wrap
  end
end
