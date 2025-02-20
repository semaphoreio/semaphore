defprotocol RepositoryHub.Server.DescribeRemoteRepositoryAction do
  alias InternalApi.Repository.{DescribeRemoteRepositoryRequest, DescribeRemoteRepositoryResponse}

  @spec execute(t, DescribeRemoteRepositoryRequest.t()) :: Toolkit.tupled_result(DescribeRemoteRepositoryResponse.t())
  def execute(adapter, request)

  @spec validate(t, DescribeRemoteRepositoryRequest.t()) :: Toolkit.tupled_result(DescribeRemoteRepositoryRequest.t())
  def validate(adapter, request)
end
