defmodule RepositoryHub.Stub.ProjectHub do
  @moduledoc false

  alias InternalApi.Projecthub

  use GRPC.Server, service: InternalApi.Projecthub.ProjectService.Service
  alias Util.Proto

  @org_id "4b0d4a1c-5d7e-4f3a-9a52-2f1e0c6b8d10"

  def org_id, do: @org_id

  def describe(request, _stream) do
    owner_id = UUID.uuid4()
    id = Map.get(request, :id, Ecto.UUID.generate())

    Projecthub.DescribeResponse
    |> Proto.deep_new!(%{
      project: %{
        id: id,
        creator_id: owner_id,
        metadata: %{id: id, owner_id: owner_id, org_id: @org_id}
      },
      metadata: %{
        status: %{
          code: :OK
        }
      }
    })
  end
end
