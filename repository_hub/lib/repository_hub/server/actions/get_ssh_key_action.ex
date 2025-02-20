defprotocol RepositoryHub.Server.GetSshKeyAction do
  alias InternalApi.Repository.{GetSshKeyRequest, GetSshKeyResponse}

  @spec execute(t, GetSshKeyRequest.t()) :: Toolkit.tupled_result(GetSshKeyResponse.t())
  def execute(adapter, request)

  @spec validate(t, GetSshKeyRequest.t()) :: Toolkit.tupled_result(GetSshKeyRequest.t())
  def validate(adapter, request)
end
