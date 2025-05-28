defimpl RepositoryHub.Server.DescribeRemoteRepositoryAction, for: RepositoryHub.BitbucketAdapter do
  # credo:disable-for-this-file
  alias RepositoryHub.{
    Validator,
    Toolkit,
    BitbucketAdapter,
    BitbucketClient,
    Model
  }

  alias InternalApi.Repository.{
    RemoteRepository,
    DescribeRemoteRepositoryResponse
  }

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    alias Ecto.Multi

    Multi.new()
    |> Multi.run(:git_repository, fn _repo, _results ->
      Model.GitRepository.from_bitbucket(request.url)
    end)
    |> Multi.run(:bitbucket_token, fn _repo, _context ->
      BitbucketAdapter.fetch_token(request.user_id)
    end)
    |> Multi.run(:bitbucket_repository, fn _repo, context ->
      BitbucketClient.find_repository(
        %{
          repo_owner: context.git_repository.owner,
          repo_name: context.git_repository.repo
        },
        token: context.bitbucket_token
      )
    end)
    |> Multi.run(:remote_repository, fn _repo, context ->
      addable = context.bitbucket_repository.with_admin_access?

      reason =
        if context.bitbucket_repository.with_admin_access? do
          ""
        else
          "The user does not have admin access to this repository."
        end

      %RemoteRepository{
        id: context.bitbucket_repository.id,
        name: context.bitbucket_repository.name,
        description: context.bitbucket_repository.description,
        url: context.git_repository.ssh_git_url,
        full_name: context.bitbucket_repository.full_name,
        addable: addable,
        reason: reason
      }
      |> wrap()
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      %DescribeRemoteRepositoryResponse{
        remote_repository: context.remote_repository
      }
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :user_id}, :is_uuid],
        chain: [{:from!, :integration_type}, :is_bitbucket_integration_type],
        chain: [
          {:from!, :url},
          any: [:is_bitbucket_url],
          error_message: "only bitbucket urls are allowed"
        ]
      ]
    )
  end
end
