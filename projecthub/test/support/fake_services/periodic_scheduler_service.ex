defmodule Support.FakeServices.PeriodicSchedulerService do
  @moduledoc false
  require Logger

  use GRPC.Server, service: InternalApi.PeriodicScheduler.PeriodicService.Service

  def list(req, stream) do
    FunRegistry.run!(__MODULE__, :list, [req, stream])
  end

  def delete(req, stream) do
    FunRegistry.run!(__MODULE__, :delete, [req, stream])
  end

  def apply(req, stream) do
    FunRegistry.run!(__MODULE__, :apply, [req, stream])
  end

  def persist(req, stream) do
    FunRegistry.run!(__MODULE__, :persist, [req, stream])
  end
end
