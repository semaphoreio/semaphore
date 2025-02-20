defprotocol RepositoryHub.Server.CreateBuildStatusAction do
  alias InternalApi.Repository.CreateBuildStatusRequest

  @spec execute(t, CreateBuildStatusRequest.t()) :: Toolkit.tupled_result(Google.Protobuf.Empty.t())
  def execute(adapter, request)

  @spec validate(t, CreateBuildStatusRequest.t()) :: Toolkit.tupled_result(CreateBuildStatusRequest.t())
  def validate(adapter, request)
end
