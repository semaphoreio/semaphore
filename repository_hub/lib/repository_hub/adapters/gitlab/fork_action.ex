defimpl RepositoryHub.Server.ForkAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Toolkit, Validator, Model}
  alias InternalApi.Repository.{RemoteRepository, ForkResponse}
  alias Ecto.Multi
  import Toolkit

  @impl true
  def execute(_adapter, request) do
    Multi.new()
    |> Multi.run(:git_repository, fn _repo, _results ->
      Model.GitRepository.from_gitlab(request.url)
    end)
    |> Multi.run(:gitlab_token, fn _repo, _context ->
      GitlabAdapter.fetch_token(request.user_id)
    end)
    |> Multi.run(:gitlab_repository, fn _repo, context ->
      GitlabClient.find_repository(
        %{
          repo_owner: context.git_repository.owner,
          repo_name: context.git_repository.repo
        },
        token: context.gitlab_token
      )
    end)
    |> Multi.run(:forked_repository, fn _repo, context ->
      # we don't get the url
      GitlabClient.fork(
        %{
          repo_owner: context.git_repository.owner,
          repo_name: context.git_repository.repo
        },
        token: context.gitlab_token
      )
    end)
    |> Multi.run(:remote_repository, fn _repo, context ->
      %RemoteRepository{
        id: context.gitlab_repository.id,
        name: context.gitlab_repository.name,
        description: context.gitlab_repository.description,
        url: context.forked_repository.url,
        full_name: context.gitlab_repository.full_name,
        addable: true,
        reason: ""
      }
      |> wrap()
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      %ForkResponse{remote_repository: context.remote_repository}
      |> wrap()
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :user_id}, :is_uuid],
        chain: [{:from!, :integration_type}, :is_gitlab_integration_type],
        chain: [
          {:from!, :url},
          any: [:is_gitlab_url],
          error_message: "Only gitlab urls are allowed."
        ]
      ]
    )
  end
end
