defmodule Support.FakeServices.CacheService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Cache.CacheService.Service

  def create(req, stream) do
    FunRegistry.run!(__MODULE__, :create, [req, stream])
  end

  def provision_ceph_cache(req, stream) do
    FunRegistry.run!(__MODULE__, :provision_ceph_cache, [req, stream])
  end
end
