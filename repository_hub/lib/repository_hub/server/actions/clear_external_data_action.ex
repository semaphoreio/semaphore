defprotocol RepositoryHub.Server.ClearExternalDataAction do
  alias InternalApi.Repository.{ClearExternalDataRequest, ClearExternalDataResponse}

  @spec execute(t, ClearExternalDataRequest.t()) :: Toolkit.tupled_result(ClearExternalDataResponse.t())
  def execute(adapter, request)

  @spec validate(t, ClearExternalDataRequest.t()) :: Toolkit.tupled_result(ClearExternalDataRequest.t())
  def validate(adapter, request)
end
