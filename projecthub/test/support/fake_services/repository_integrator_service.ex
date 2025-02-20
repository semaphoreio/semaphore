defmodule Support.FakeServices.RepositoryIntegratorService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Service

  def get_token(req, stream) do
    FunRegistry.run!(__MODULE__, :get_token, [req, stream])
  end
end
