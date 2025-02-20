defprotocol RepositoryHub.Server.CheckWebhookAction do
  alias InternalApi.Repository.{CheckWebhookRequest, CheckWebhookResponse}

  @type request :: CheckWebhookRequest.t()
  @type response :: CheckWebhookResponse.t()

  @spec execute(t, CheckWebhookRequest.t()) :: Toolkit.tupled_result(CheckWebhookResponse.t())
  def execute(adapter, request)

  @spec validate(t, CheckWebhookRequest.t()) :: Toolkit.tupled_result(CheckWebhookRequest.t())
  def validate(adapter, request)
end
