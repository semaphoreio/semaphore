defmodule Support.FakeServices.RbacService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.RBAC.RBAC.Service

  def list_user_permissions(req, stream) do
    FunRegistry.run!(__MODULE__, :list_user_permissions, [req, stream])
  end
end
