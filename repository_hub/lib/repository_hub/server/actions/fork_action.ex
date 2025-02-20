defprotocol RepositoryHub.Server.ForkAction do
  alias InternalApi.Repository.{ForkRequest, ForkResponse}

  @spec execute(t, ForkRequest.t()) :: Toolkit.tupled_result(ForkResponse.t())
  def execute(adapter, request)

  @spec validate(t, ForkRequest.t()) :: Toolkit.tupled_result(ForkRequest.t())
  def validate(adapter, request)
end
