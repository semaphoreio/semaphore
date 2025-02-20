defprotocol RepositoryHub.Server.CheckDeployKeyAction do
  alias InternalApi.Repository.{CheckDeployKeyRequest, CheckDeployKeyResponse}

  @spec execute(t, CheckDeployKeyRequest.t()) :: Toolkit.tupled_result(CheckDeployKeyResponse.t())
  def execute(adapter, request)

  @spec validate(t, CheckDeployKeyRequest.t()) :: Toolkit.tupled_result(CheckDeployKeyRequest.t())
  def validate(adapter, request)
end
