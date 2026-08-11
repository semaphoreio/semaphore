defmodule RepositoryHub.Stub.RepositoryIntegrator do
  @moduledoc false

  alias InternalApi.RepositoryIntegrator

  use GRPC.Server, service: RepositoryIntegrator.RepositoryIntegratorService.Service

  def get_token(request, _stream) do
    token = build_token(request)
    expires_at = RepositoryHub.Toolkit.to_proto_time(DateTime.utc_now())

    %RepositoryIntegrator.GetTokenResponse{
      token: token,
      expires_at: expires_at
    }
  end

  defp build_token(%{integration_type: :GITHUB_APP, repository_remote_id: repository_remote_id}),
    do: "gha-#{repository_remote_id || ""}"

  defp build_token(_request), do: UUID.uuid4()
end
