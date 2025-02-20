defprotocol RepositoryHub.Server.RegenerateDeployKeyAction do
  alias InternalApi.Repository.{RegenerateDeployKeyRequest, RegenerateDeployKeyResponse}

  @spec execute(t, RegenerateDeployKeyRequest.t()) :: Toolkit.tupled_result(RegenerateDeployKeyResponse.t())
  def execute(adapter, request)

  @spec validate(t, RegenerateDeployKeyRequest.t()) :: Toolkit.tupled_result(RegenerateDeployKeyRequest.t())
  def validate(adapter, request)
end
