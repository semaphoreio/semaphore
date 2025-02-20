defmodule Support.Fake.OrganizationService do
  use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end
end
