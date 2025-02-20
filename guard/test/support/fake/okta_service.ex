defmodule Support.Fake.OktaService do
  use GRPC.Server, service: InternalApi.Okta.Okta.Service

  def list(req, stream) do
    FunRegistry.run!(__MODULE__, :list, [req, stream])
  end
end
