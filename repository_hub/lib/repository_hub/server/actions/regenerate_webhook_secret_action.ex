defprotocol RepositoryHub.Server.RegenerateWebhookSecretAction do
  alias InternalApi.Repository.{RegenerateWebhookSecretRequest, RegenerateWebhookSecretResponse}

  @spec execute(t, RegenerateWebhookSecretRequest.t()) :: Toolkit.tupled_result(RegenerateWebhookSecretResponse.t())
  def execute(adapter, request)

  @spec validate(t, RegenerateWebhookSecretRequest.t()) :: Toolkit.tupled_result(RegenerateWebhookSecretRequest.t())
  def validate(adapter, request)
end
