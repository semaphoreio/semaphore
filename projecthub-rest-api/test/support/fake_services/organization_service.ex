defmodule Support.FakeServices.OrganizationService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

  def repository_integrators(req, stream) do
    FunRegistry.run!(__MODULE__, :repository_integrators, [req, stream])
  end

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end
end
