defmodule Support.FakeServices.SwitchService do
  use GRPC.Server, service: InternalApi.Gofer.Switch.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def list_trigger_events(req, stream) do
    FunRegistry.run!(__MODULE__, :list_trigger_events, [req, stream])
  end

  def trigger(req, stream) do
    FunRegistry.run!(__MODULE__, :trigger, [req, stream])
  end
end
