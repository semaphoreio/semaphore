defmodule Support.Stubs.McpGrant do
  def init do
    __MODULE__.Grpc.init()
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(
        McpGrantMock,
        :describe_consent_challenge,
        &__MODULE__.describe_consent_challenge/2
      )

      GrpcMock.stub(
        McpGrantMock,
        :approve_consent_challenge,
        &__MODULE__.approve_consent_challenge/2
      )

      GrpcMock.stub(
        McpGrantMock,
        :deny_consent_challenge,
        &__MODULE__.deny_consent_challenge/2
      )
    end

    def describe_consent_challenge(_request, _stream), do: raise_not_found()
    def approve_consent_challenge(_request, _stream), do: raise_not_found()
    def deny_consent_challenge(_request, _stream), do: raise_not_found()

    defp raise_not_found do
      raise GRPC.RPCError,
        status: GRPC.Status.not_found(),
        message: "Consent challenge not found or expired"
    end
  end
end
