defprotocol RepositoryHub.Server.DeleteAction do
  alias InternalApi.Repository.{DeleteRequest, DeleteResponse}

  @spec execute(t, DeleteRequest.t()) :: Toolkit.tupled_result(DeleteResponse.t())
  def execute(adapter, request)

  @spec validate(t, DeleteRequest.t()) :: Toolkit.tupled_result(DeleteRequest.t())
  def validate(adapter, request)
end
