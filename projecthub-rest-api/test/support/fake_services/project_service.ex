defmodule Support.FakeServices.ProjectService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Projecthub.ProjectService.Service

  def list(req, stream) do
    FunRegistry.run!(__MODULE__, :list, [req, stream])
  end

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def create(req, stream) do
    FunRegistry.run!(__MODULE__, :create, [req, stream])
  end

  def update(req, stream) do
    FunRegistry.run!(__MODULE__, :update, [req, stream])
  end

  def destroy(req, stream) do
    FunRegistry.run!(__MODULE__, :destroy, [req, stream])
  end
end
