defmodule RepositoryHub.Stub.RepositoryIntegrator do
  @moduledoc false

  alias InternalApi.RepositoryIntegrator

  use GRPC.Server, service: RepositoryIntegrator.RepositoryIntegratorService.Service

  def get_token(_request, _stream) do
    token = UUID.uuid4()
    expires_at = RepositoryHub.Toolkit.to_proto_time(DateTime.utc_now())

    %RepositoryIntegrator.GetTokenResponse{
      token: token,
      expires_at: expires_at
    }
  end
end
