defmodule Support.FakeServices.ArtifactService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Artifacthub.ArtifactService.Service

  def create(req, stream) do
    FunRegistry.run!(__MODULE__, :create, [req, stream])
  end

  def destroy(req, stream) do
    FunRegistry.run!(__MODULE__, :destroy, [req, stream])
  end
end
