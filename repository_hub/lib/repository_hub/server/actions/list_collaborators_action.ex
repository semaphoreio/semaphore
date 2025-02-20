defprotocol RepositoryHub.Server.ListCollaboratorsAction do
  alias InternalApi.Repository.{ListCollaboratorsRequest, ListCollaboratorsResponse}
  alias GRPC.Server.Stream, as: ServerStream

  @spec execute(t, ListCollaboratorsRequest.t(), ServerStream.t()) ::
          Toolkit.tupled_result(ListCollaboratorsResponse.t())
  def execute(adapter, request, stream)

  @spec validate(t, ListCollaboratorsRequest.t()) :: Toolkit.tupled_result(ListCollaboratorsRequest.t())
  def validate(adapter, request)
end
