defmodule Support.FakeServices.FeatureService do
  use GRPC.Server, service: InternalApi.Feature.FeatureService.Service

  def list_organization_features(req, stream) do
    require Logger
    FunRegistry.run!(__MODULE__, :list_organization_features, [req, stream])
  end
end
