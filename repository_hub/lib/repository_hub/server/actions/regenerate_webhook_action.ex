defprotocol RepositoryHub.Server.RegenerateWebhookAction do
  alias InternalApi.Repository.{RegenerateWebhookRequest, RegenerateWebhookResponse}

  @spec execute(t, RegenerateWebhookRequest.t()) :: Toolkit.tupled_result(RegenerateWebhookResponse.t())
  def execute(adapter, request)

  @spec validate(t, RegenerateWebhookRequest.t()) :: Toolkit.tupled_result(RegenerateWebhookRequest.t())
  def validate(adapter, request)
end
