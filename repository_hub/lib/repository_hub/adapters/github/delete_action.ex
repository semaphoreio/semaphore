defimpl RepositoryHub.Server.DeleteAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Model
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, Model, GithubClient}
  alias InternalApi.Repository.DeleteResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    with {:ok, adapter_context} <- GithubAdapter.context(adapter, request.repository_id) do
      Multi.new()
      |> Multi.put(:repository, adapter_context.repository)
      |> Multi.put(:github_token, adapter_context.github_token)
      |> Multi.run(:deploy_key, fn _repo, context ->
        Model.DeployKeyQuery.get_by_repository_id(context.repository.id)
        |> unwrap_error(fn _ ->
          wrap(:not_found)
        end)
      end)
      |> Multi.run(:remove_deploy_key, fn
        _repo, %{deploy_key: :not_found} ->
          wrap(:ok)

        _, context ->
          Model.DeployKeyQuery.delete(context.deploy_key.id)
      end)
      |> Multi.run(:remove_github_key, fn
        _repo, %{deploy_key: :not_found} ->
          "Skiping GitHub deploy key removal - deploy key not found"
          |> log(level: :info)

          wrap(:ok)

        _, context ->
          GithubClient.remove_deploy_key(
            %{
              repo_owner: context.repository.owner,
              repo_name: context.repository.name,
              key_id: "#{context.deploy_key.remote_id}"
            },
            token: context.github_token
          )
          |> unwrap_error(fn _ ->
            wrap(:not_found)
          end)
      end)
      |> Multi.run(:remove_webhook, fn
        _repo, %{repository: %{hook_id: ""}} ->
          "Skiping GitHub webhook removal - no hook id"
          |> log(level: :info)

          wrap(:ok)

        _, context ->
          GithubClient.remove_webhook(
            %{
              repo_owner: context.repository.owner,
              repo_name: context.repository.name,
              webhook_id: context.repository.hook_id
            },
            token: context.github_token
          )
          |> unwrap_error(fn _ ->
            wrap(:not_found)
          end)
      end)
      |> Multi.run(:delete_repository, fn _repo, context ->
        Model.RepositoryQuery.delete(context.repository.id)
      end)
      |> RepositoryHub.Repo.transaction()
      |> unwrap(fn context ->
        Model.Repositories.to_grpc_model(context.repository)
        |> then(fn grpc_repository ->
          %DeleteResponse{repository: grpc_repository}
          |> wrap()
        end)
      end)
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(chain: [{:from!, :repository_id}, :is_uuid])
  end
end
