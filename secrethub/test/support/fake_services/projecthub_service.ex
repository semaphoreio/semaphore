defmodule Support.FakeServices.ProjecthubService do
  use GRPC.Server, service: InternalApi.Projecthub.ProjectService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def list(req, stream) do
    FunRegistry.run!(__MODULE__, :list, [req, stream])
  end
end
