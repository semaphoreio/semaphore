defmodule Notifications.Api.InternalApi.List do
  require Logger

  alias InternalApi.Notifications, as: Api

  alias Notifications.Api.InternalApi.Serialization

  @default_page_size 100
  @page_size_limit 100

  def run(req = %Api.ListRequest{}) do
    org_id = req.metadata.org_id

    with {:ok, page_size} <- extract_page_size(req),
         {:ok, notifications, token} <-
           Notifications.Util.List.query(org_id, page_size, req.page_token, req.order) do
      notifications =
        notifications
        |> Enum.map(fn n ->
          Serialization.serialize(n)
        end)

      Api.ListResponse.new(
        next_page_token: token,
        notifications: notifications
      )
    else
      {:error, :invalid_argument, message} ->
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: message

      {:error, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  defp extract_page_size(req) do
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
