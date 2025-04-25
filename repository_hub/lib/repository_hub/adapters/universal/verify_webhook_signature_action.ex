defimpl RepositoryHub.Server.VerifyWebhookSignatureAction, for: RepositoryHub.UniversalAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.Model.{Repositories, RepositoryQuery}

  alias InternalApi.Repository.VerifyWebhookSignatureResponse

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    with {:ok, repository} <- RepositoryQuery.get_by_id(request.repository_id),
         {:ok, result} <-
           Repositories.hook_signature_valid?(
             repository,
             request.payload,
             request.signature
           ) do
      %VerifyWebhookSignatureResponse{valid: result}
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :organization_id}, :is_uuid],
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :payload}, :is_string],
        chain: [{:from!, :signature}, :is_string]
      ]
    )
  end
end
