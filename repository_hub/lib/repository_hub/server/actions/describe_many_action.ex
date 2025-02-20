defprotocol RepositoryHub.Server.DescribeManyAction do
  alias InternalApi.Repository.{DescribeManyRequest, DescribeManyResponse}

  @spec execute(t, DescribeManyRequest.t()) :: Toolkit.tupled_result(DescribeManyResponse.t())
  def execute(adapter, request)

  @spec validate(t, DescribeManyRequest.t()) :: Toolkit.tupled_result(DescribeManyRequest.t())
  def validate(adapter, request)
end
