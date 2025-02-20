defprotocol RepositoryHub.Server.ListAccessibleRepositoriesAction do
  alias InternalApi.Repository.{ListAccessibleRepositoriesRequest, ListAccessibleRepositoriesResponse}

  @spec execute(t, ListAccessibleRepositoriesRequest.t()) ::
          Toolkit.tupled_result(ListAccessibleRepositoriesResponse.t())
  def execute(adapter, request)

  @spec validate(t, ListAccessibleRepositoriesRequest.t()) ::
          Toolkit.tupled_result(ListAccessibleRepositoriesRequest.t())
  def validate(adapter, request)
end
