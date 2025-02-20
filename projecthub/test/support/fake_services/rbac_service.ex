defmodule Support.FakeServices.RbacService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.RBAC.RBAC.Service

  def list_roles(req, stream) do
    FunRegistry.run!(__MODULE__, :list_roles, [req, stream])
  end

  def assign_role(req, stream) do
    FunRegistry.run!(__MODULE__, :assign_role, [req, stream])
  end
end
