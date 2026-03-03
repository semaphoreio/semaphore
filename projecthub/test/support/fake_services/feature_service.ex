defmodule Support.FakeServices.FeatureService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Feature.FeatureService.Service

  def list_organization_features(req, stream) do
    FunRegistry.run!(__MODULE__, :list_organization_features, [req, stream])
  end

  def list_features(req, stream) do
    FunRegistry.run!(__MODULE__, :list_features, [req, stream])
  end
end
