defmodule Notifications.Api.PublicApi.List do
  require Logger

  alias Semaphore.Notifications.V1alpha.ListNotificationsResponse

  alias Notifications.Auth
  alias Notifications.Api.PublicApi.Serialization

  @default_page_size 100
  @page_size_limit 300

  def run(req, org_id, user_id) do
    Logger.info("#{inspect(org_id)} #{inspect(user_id)}")

    with {:ok, page_size} <- extract_page_size(req),
         {:ok, :authorized} <- Auth.can_view?(user_id, org_id),
         {:ok, notifications, token} <-
           Notifications.Util.List.query(org_id, page_size, req.page_token, req.order) do
      Logger.info("#{inspect(org_id)} #{inspect(user_id)}")

      notifications =
        notifications
        |> Enum.map(fn n ->
          Serialization.serialize(n)
        end)

      Logger.info("#{inspect(org_id)} #{inspect(user_id)}")

      ListNotificationsResponse.new(
        next_page_token: token,
        notifications: notifications
      )
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "Can't list notifications in organization"

      {:error, :invalid_argument, message} ->
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: message

      {:error, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def extract_page_size(req) do
    cond do
      req.page_size == 0 ->
        {:ok, @default_page_size}

      req.page_size > @page_size_limit ->
        {:error, :invalid_argument, "Page size can't exceed #{@page_size_limit}"}

      true ->
        {:ok, req.page_size}
    end
  end
end
