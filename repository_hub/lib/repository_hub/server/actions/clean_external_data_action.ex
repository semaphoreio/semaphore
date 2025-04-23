defmodule RepositoryHub.Server.CleanExternalDataAction do
  alias InternalApi.Repository.{CleanExternalDataRequest, CleanExternalDataResponse}

  @spec execute(t, CleanExternalDataRequest.t()) :: Toolkit.tupled_result(CleanExternalDataResponse.t())
  def execute(adapter, request)

  @spec validate(t, CleanExternalDataRequest.t()) :: Toolkit.tupled_result(CleanExternalDataRequest.t())
  def validate(adapter, request)
end
