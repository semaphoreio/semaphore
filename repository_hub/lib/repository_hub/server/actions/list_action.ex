defprotocol RepositoryHub.Server.ListAction do
  alias InternalApi.Repository.{ListRequest, ListResponse}

  @spec execute(t, ListRequest.t()) :: Toolkit.tupled_result(ListResponse.t())
  def execute(adapter, request)

  @spec validate(t, ListRequest.t()) :: Toolkit.tupled_result(ListRequest.t())
  def validate(adapter, request)
end
