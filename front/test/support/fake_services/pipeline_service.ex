defmodule Support.FakeServices.PipelineService do
  use GRPC.Server, service: InternalApi.Plumber.PipelineService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def describe_topology(req, stream) do
    FunRegistry.run!(__MODULE__, :describe_topology, [req, stream])
  end

  def describe_many(req, stream) do
    FunRegistry.run!(__MODULE__, :describe_many, [req, stream])
  end

  def list(req, stream) do
    FunRegistry.run!(__MODULE__, :list, [req, stream])
  end

  def terminate(req, stream) do
    FunRegistry.run!(__MODULE__, :terminate, [req, stream])
  end

  def list_grouped(req, stream) do
    FunRegistry.run!(__MODULE__, :list_grouped, [req, stream])
  end

  def list_keyset(req, stream) do
    FunRegistry.run!(__MODULE__, :list_keyset, [req, stream])
  end
end
