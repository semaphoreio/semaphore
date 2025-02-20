defmodule Notifications.Api.InternalApi.Describe do
  require Logger

  alias Notifications.Models.Notification, as: Model
  alias Notifications.Api.InternalApi.Serialization
  alias InternalApi.Notifications.DescribeResponse

  def run(req) do
    org_id = req.metadata.org_id

    find_by_id_or_name(org_id, req.id, req.name)
    |> case do
      {:ok, n} ->
        %DescribeResponse{notification: Serialization.serialize(n)}

      {:error, :not_found} ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "Notification not found"

      {:error, :invalid_argument, message} ->
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: message

      {:error, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  defp find_by_id_or_name(org_id, id, name) do
    cond do
      id != "" ->
        Model.find(org_id, id)

      name != "" ->
        Model.find_by_name(org_id, name)

      true ->
        {:error, :invalid_argument, "Name or ID must be provided"}
    end
  end
end
