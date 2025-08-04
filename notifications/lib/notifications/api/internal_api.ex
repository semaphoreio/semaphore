defmodule Notifications.Api.InternalApi do
  require Logger

  alias InternalApi.Notifications, as: Api

  use GRPC.Server, service: Api.NotificationsApi.Service
  use Sentry.Grpc, service: Api.NotificationsApi.Service

  def list(req, _call) do
    IO.puts("LIST INTERNAL")
    IO.inspect(req)
    Notifications.Api.InternalApi.List.run(req)
  end

  def describe(req, _call) do
    Notifications.Api.InternalApi.Describe.run(req)
  end

  def create(req, _call) do
    Notifications.Api.InternalApi.Create.run(req)
  end

  def update(req, _call) do
    Notifications.Api.InternalApi.Update.run(req)
  end

  def destroy(req, _call) do
    Notifications.Api.InternalApi.Destroy.run(req)
  end
end
