defmodule Notifications.Api.PublicApi do
  require Logger

  alias Semaphore.Notifications.V1alpha.NotificationsApi

  use GRPC.Server, service: NotificationsApi.Service
  use Sentry.Grpc, service: NotificationsApi.Service

  def list_notifications(req, call) do
    {org_id, user_id} = call |> extract_headers

    Notifications.Api.PublicApi.List.run(req, org_id, user_id)
  end

  def get_notification(req, call) do
    {org_id, user_id} = call |> extract_headers

    Notifications.Api.PublicApi.Get.run(req, org_id, user_id)
  end

  def create_notification(notification, call) do
    {org_id, user_id} = extract_headers(call)

    Notifications.Api.PublicApi.Create.run(notification, org_id, user_id)
  end

  def update_notification(req, call) do
    {org_id, user_id} = call |> extract_headers

    Notifications.Api.PublicApi.Update.run(req, org_id, user_id)
  end

  def delete_notification(req, call) do
    {org_id, user_id} = call |> extract_headers

    Notifications.Api.PublicApi.Delete.run(req, org_id, user_id)
  end

  defp extract_headers(call) do
    call
    |> GRPC.Stream.get_headers()
    |> Map.take(["x-semaphore-org-id", "x-semaphore-user-id"])
    |> Map.values()
    |> List.to_tuple()
  end
end
