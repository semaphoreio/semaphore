defmodule Support.Fake.RepositoryService do
  use GRPC.Server, service: InternalApi.Repository.RepositoryService.Service

  def list_collaborators(req, stream) do
    FunRegistry.run!(__MODULE__, :list_collaborators, [req, stream])
  end
end
