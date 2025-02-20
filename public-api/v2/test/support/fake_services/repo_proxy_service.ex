defmodule Support.FakeServices.RepoProxyService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.RepoProxy.RepoProxyService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def describe_many(req, stream) do
    FunRegistry.run!(__MODULE__, :describe_many, [req, stream])
  end

  def list_blocked_hooks(req, stream) do
    FunRegistry.run!(__MODULE__, :list_blocked_hooks, [req, stream])
  end

  def schedule_blocked_hook(req, stream) do
    FunRegistry.run!(__MODULE__, :schedule_blocked_hook, [req, stream])
  end

  def create(req, stream) do
    FunRegistry.run!(__MODULE__, :create, [req, stream])
  end
end
