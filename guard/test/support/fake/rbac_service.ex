defmodule Support.Fake.RbacService do
  use GRPC.Server, service: InternalApi.RBAC.RBAC.Service

  def assign_role(req, stream) do
    FunRegistry.run!(__MODULE__, :assign_role, [req, stream])
  end

  def list_project_members(req, stream) do
    FunRegistry.run!(__MODULE__, :list_project_members, [req, stream])
  end

  def list_accessible_orgs(req, stream) do
    FunRegistry.run!(__MODULE__, :list_accessible_orgs, [req, stream])
  end

  def list_roles(req, stream) do
    FunRegistry.run!(__MODULE__, :list_roles, [req, stream])
  end

  def list_members(req, stream) do
    FunRegistry.run!(__MODULE__, :list_members, [req, stream])
  end
end
