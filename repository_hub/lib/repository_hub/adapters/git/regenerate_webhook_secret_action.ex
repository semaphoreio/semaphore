defimpl RepositoryHub.Server.RegenerateWebhookSecretAction, for: RepositoryHub.GitAdapter do
  alias RepositoryHub.{GitAdapter, Toolkit, Validator, Model}
  alias InternalApi.Repository.RegenerateWebhookSecretResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitAdapter.context(adapter, request.repository_id),
         {:ok, {secret, secret_enc}} <- Model.Repositories.generate_hook_secret(context.repository),
         {:ok, _} <- update_repository_secret(context.repository, secret_enc) do
      %RegenerateWebhookSecretResponse{
        secret: secret
      }
      |> wrap()
    end
  end

  defp update_repository_secret(repository, secret_enc) do
    Model.RepositoryQuery.update(repository, %{
      hook_id: repository.id,
      hook_secret_enc: secret_enc
    })
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
