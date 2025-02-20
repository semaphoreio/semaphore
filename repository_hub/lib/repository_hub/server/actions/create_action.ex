defprotocol RepositoryHub.Server.CreateAction do
  alias InternalApi.Repository.{CreateRequest, CreateResponse}

  @spec execute(t, CreateRequest.t()) :: Toolkit.tupled_result(CreateResponse.t())
  def execute(adapter, request)

  @spec validate(t, CreateRequest.t()) :: Toolkit.tupled_result(CreateRequest.t())
  def validate(adapter, request)
end
