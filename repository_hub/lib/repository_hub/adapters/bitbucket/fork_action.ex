defimpl RepositoryHub.Server.ForkAction, for: RepositoryHub.BitbucketAdapter do
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
    ForkResponse
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
    |> Multi.run(:forked_repository, fn _repo, context ->
      BitbucketClient.fork(
        %{
          repo_owner: context.git_repository.owner,
          repo_name: context.git_repository.repo
        },
        token: context.bitbucket_token
      )
    end)
    |> Multi.run(:remote_repository, fn _repo, context ->
      %RemoteRepository{
        id: "",
        name: context.bitbucket_repository.name,
        description: context.bitbucket_repository.description,
        url: context.forked_repository.url,
        full_name: context.bitbucket_repository.full_name,
        addable: true,
        reason: ""
      }
      |> wrap()
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      %ForkResponse{remote_repository: context.remote_repository}
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :user_id}, :is_uuid],
        chain: [{:from!, :integration_type}, check: &valid_integration_type/1],
        chain: [
          {:from!, :url},
          any: [:is_bitbucket_url],
          error_message: "Only bitbucket urls are allowed."
        ]
      ]
    )
  end

  defp valid_integration_type(status) do
    status in [
      :BITBUCKET
    ]
  end
end
