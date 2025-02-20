defmodule RepositoryHub.Stub.ProjectHub do
  @moduledoc false

  alias InternalApi.Projecthub

  use GRPC.Server, service: InternalApi.Projecthub.ProjectService.Service
  alias Util.Proto

  def describe(request, _stream) do
    owner_id = UUID.uuid4()
    id = Map.get(request, :id, Ecto.UUID.generate())

    Projecthub.DescribeResponse
    |> Proto.deep_new!(%{
      project: %{
        id: id,
        creator_id: owner_id,
        metadata: %{owner_id: owner_id}
      },
      metadata: %{
        status: %{
          code: :OK
        }
      }
    })
  end
end
