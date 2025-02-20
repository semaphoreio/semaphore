defprotocol RepositoryHub.Server.VerifyWebhookSignatureAction do
  alias InternalApi.Repository.{VerifyWebhookSignatureRequest, VerifyWebhookSignatureResponse}

  @spec execute(t, VerifyWebhookSignatureRequest.t()) :: Toolkit.tupled_result(VerifyWebhookSignatureResponse.t())
  def execute(adapter, request)

  @spec validate(t, VerifyWebhookSignatureRequest.t()) :: Toolkit.tupled_result(VerifyWebhookSignatureRequest.t())
  def validate(adapter, request)
end
