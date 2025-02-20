defprotocol RepositoryHub.Server.GetFileAction do
  alias InternalApi.Repository.{GetFileRequest, GetFileResponse}

  @spec execute(t, GetFileRequest.t()) :: Toolkit.tupled_result(GetFileResponse.t())
  def execute(adapter, request)

  @spec validate(t, GetFileRequest.t()) :: Toolkit.tupled_result(GetFileRequest.t())
  def validate(adapter, request)
end
