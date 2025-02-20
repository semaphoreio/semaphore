defprotocol RepositoryHub.Server.DescribeRevisionAction do
  alias InternalApi.Repository.{DescribeRevisionRequest, DescribeRevisionResponse}

  @spec execute(t, DescribeRevisionRequest.t()) :: Toolkit.tupled_result(DescribeRevisionResponse.t())
  def execute(adapter, request)

  @spec validate(t, DescribeRevisionRequest.t()) :: Toolkit.tupled_result(DescribeRevisionRequest.t())
  def validate(adapter, request)
end
