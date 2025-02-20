defprotocol RepositoryHub.Server.DescribeAction do
  alias InternalApi.Repository.{DescribeRequest, DescribeResponse}

  @spec execute(t, DescribeRequest.t()) :: Toolkit.tupled_result(DescribeResponse.t())
  def execute(adapter, request)

  @spec validate(t, DescribeRequest.t()) :: Toolkit.tupled_result(DescribeRequest.t())
  def validate(adapter, request)
end
