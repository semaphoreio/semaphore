defimpl RepositoryHub.Server.RegenerateWebhookAction, for: RepositoryHub.GitAdapter do
  alias RepositoryHub.{GitAdapter, Toolkit, Validator, Model}
  alias InternalApi.Repository.RegenerateWebhookResponse
  import Toolkit
  alias Model.RepositoryQuery


  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitAdapter.context(adapter, request.repository_id) do
      regenerate_webhook(request, context.repository)
    end
  end

  def regenerate_webhook(request, repository) do
    repository
    |> RepositoryQuery.update(%{
      connected: true
    })
    |> case do
      {:ok, _} ->
        %RegenerateWebhookResponse{
          webhook: %InternalApi.Repository.Webhook{
            url: repository.url
          }
        }
        |> wrap()
      _ ->
        {:error, "Failed to regenerate webhook"}
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
