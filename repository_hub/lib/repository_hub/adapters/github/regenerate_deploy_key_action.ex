defimpl RepositoryHub.Server.RegenerateDeployKeyAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.Model
  alias RepositoryHub.{GithubAdapter, GithubClient}
  alias InternalApi.Repository.RegenerateDeployKeyResponse

  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    with {:ok, adapter_context} <- GithubAdapter.context(adapter, request.repository_id) do
      Multi.new()
      |> Multi.put(:repository, adapter_context.repository)
      |> Multi.put(:github_token, adapter_context.github_token)
      |> Multi.run(:deploy_key, fn _repo, _results ->
        Model.DeployKeyQuery.get_by_repository_id(request.repository_id)
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
      |> Multi.run(:remove_in_github, fn
        _repo, %{deploy_key: :not_found} ->
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
      end)
      |> Multi.run(:new_keypair, fn _, _ ->
        Model.DeployKeys.generate_private_public_key_pair()
        |> wrap()
      end)
      |> Multi.run(:new_github_key, fn _repo, context ->
        {_private_key, public_key} = context.new_keypair

        GithubClient.create_deploy_key(
          %{
            repo_owner: context.repository.owner,
            repo_name: context.repository.name,
            title: "semaphore-#{context.repository.owner}-#{context.repository.name}",
            key: public_key,
            read_only: true
          },
          token: context.github_token
        )
      end)
      |> Multi.run(:new_deploy_key, fn _repo, context ->
        {private_key, public_key} = context.new_keypair

        {:ok, private_key_enc} =
          RepositoryHub.Encryptor.encrypt(
            RepositoryHub.DeployKeyEncryptor,
            private_key,
            "semaphore-#{context.repository.project_id}"
          )

        %{
          public_key: public_key,
          private_key_enc: private_key_enc,
          deployed: true,
          remote_id: context.new_github_key.id,
          project_id: context.repository.project_id,
          repository_id: context.repository.id
        }
        |> Model.DeployKeyQuery.insert()
      end)
      |> RepositoryHub.Repo.transaction()
      |> unwrap(fn context ->
        %InternalApi.Repository.DeployKey{
          title: context.new_github_key.title,
          fingerprint: Model.DeployKeys.fingerprint(context.new_deploy_key),
          created_at: to_proto_time(context.new_deploy_key.inserted_at)
        }
        |> then(fn grpc_deploy_key ->
          %RegenerateDeployKeyResponse{deploy_key: grpc_deploy_key}
          |> wrap()
        end)
      end)
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid]
      ]
    )
  end
end
