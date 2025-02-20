defprotocol RepositoryHub.Server.UpdateAction do
  alias InternalApi.Repository.{UpdateRequest, UpdateResponse}

  @spec execute(t, UpdateRequest.t()) :: Toolkit.tupled_result(UpdateResponse.t())
  def execute(adapter, request)

  @spec validate(t, UpdateRequest.t()) :: Toolkit.tupled_result(UpdateRequest.t())
  def validate(adapter, request)
end
