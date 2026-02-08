defmodule Fake.AuthenticationService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Auth.Authentication.Service

  def authenticate_with_cookie(req, stream) do
    FunRegistry.run!(__MODULE__, :authenticate_with_cookie, [req, stream])
  end

  def authenticate(req, stream) do
    FunRegistry.run!(__MODULE__, :authenticate, [req, stream])
  end
end

defmodule Fake.OrganizationService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end
end

defmodule Fake.RbacService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.RBAC.RBAC.Service

  def list_user_permissions(req, stream) do
    FunRegistry.run!(__MODULE__, :list_user_permissions, [req, stream])
  end
end

defmodule Fake.FeatureService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Feature.FeatureService.Service

  def list_organization_features(req, stream) do
    FunRegistry.run!(__MODULE__, :list_organization_features, [req, stream])
  end

  def list_organization_machines(req, stream) do
    FunRegistry.run!(__MODULE__, :list_organization_machines, [req, stream])
  end
end

{:ok, _} = FunRegistry.start()

services = [
  Fake.AuthenticationService,
  Fake.OrganizationService,
  Fake.RbacService,
  Fake.FeatureService
]

GRPC.Server.start(services, 50_051)

formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(formatters: formatters)
ExUnit.start(trace: true, capture_log: true)
