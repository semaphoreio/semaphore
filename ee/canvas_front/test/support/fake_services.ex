defmodule Support.FakeServices do
  require Logger

  def start_fake_grpc_servers do
    init()
  end

  def init do
    services =
      [
        Support.Stubs.Delivery.Grpc,
        Support.Stubs.Organization.Grpc,
        Support.Stubs.RBAC.Grpc,
        Support.Stubs.User.Grpc,
        Support.Stubs.Feature.Grpc,
        Support.Stubs.PermissionPatrol.Grpc
      ]

    spawn(fn ->
      GRPC.Server.start(services, 50_051)
    end)
  end
end
