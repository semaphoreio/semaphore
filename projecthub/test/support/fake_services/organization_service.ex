defmodule Support.FakeServices.OrganizationService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def members(req, stream) do
    FunRegistry.run!(__MODULE__, :members, [req, stream])
  end
end
