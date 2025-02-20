defmodule Support.FakeServices.Repohub do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Repository.RepositoryService.Service

  def get_files(req, stream) do
    FunRegistry.run!(__MODULE__, :get_files, [req, stream])
  end
end
