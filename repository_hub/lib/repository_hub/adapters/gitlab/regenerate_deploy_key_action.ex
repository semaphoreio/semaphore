defimpl RepositoryHub.Server.RegenerateDeployKeyAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Toolkit, Validator, Model}
  alias InternalApi.Repository.RegenerateDeployKeyResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    adapter
    |> GitlabAdapter.multi(request.repository_id)
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
    |> Multi.run(:remove_in_gitlab, fn
      _repo, %{deploy_key: :not_found} ->
        wrap(:ok)

      _, context ->
        GitlabClient.remove_deploy_key(
          %{
            repository_id: context.repository.remote_id,
            key_id: "#{context.deploy_key.remote_id}"
          },
          token: context.gitlab_token
        )
    end)
    |> Multi.run(:new_keypair, fn _, _ ->
      Model.DeployKeys.generate_private_public_key_pair()
      |> wrap()
    end)
    |> Multi.run(:new_gitlab_key, fn _repo, context ->
      {_private_key, public_key} = context.new_keypair

      GitlabClient.create_deploy_key(
        %{
          repository_id: context.repository.remote_id,
          title: "semaphore-#{context.repository.owner}-#{context.repository.name}",
          key: public_key
        },
        token: context.gitlab_token
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
        remote_id: context.new_gitlab_key.id,
        project_id: context.repository.project_id,
        repository_id: context.repository.id
      }
      |> Model.DeployKeyQuery.insert()
    end)
    |> RepositoryHub.Repo.transaction(timeout: 30_000)
    |> unwrap(fn %{new_deploy_key: deploy_key, new_gitlab_key: gitlab_key} ->
      %RegenerateDeployKeyResponse{
        deploy_key: build_deploy_key(deploy_key, gitlab_key)
      }
      |> wrap()
    end)
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

  defp build_deploy_key(deploy_key, remote_key) do
    %InternalApi.Repository.DeployKey{
      title: remote_key.title,
      fingerprint: Model.DeployKeys.fingerprint(deploy_key),
      created_at: to_proto_time(deploy_key.inserted_at)
    }
  end
end
