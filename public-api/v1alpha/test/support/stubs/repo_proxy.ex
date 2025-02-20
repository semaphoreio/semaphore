defmodule Support.Stubs.RepoProxy do
  def init do
    __MODULE__.Grpc.init()
  end

  defmodule Grpc do
    alias InternalApi.RepoProxy.CreateResponse

    def init do
      GrpcMock.stub(RepoProxyMock, :create, &__MODULE__.create/2)
    end

    def create(req, _stream) do
      case req.project_id do
        "invalid_arg" ->
          raise GRPC.RPCError, status: GRPC.Status.invalid_argument(), message: "Invalid argument"

        "not_found" ->
          raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "Not found"

        "aborted" ->
          raise GRPC.RPCError, status: GRPC.Status.aborted(), message: "Aborted"

        _ ->
          CreateResponse.new(
            hook_id: UUID.uuid4(),
            workflow_id: UUID.uuid4(),
            pipeline_id: UUID.uuid4()
          )
      end
    end
  end
end
