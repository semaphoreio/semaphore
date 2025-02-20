defmodule Notifications.Api.InternalApi.Destroy do
  require Logger

  alias Notifications.{Repo, Models}
  alias Models.Notification, as: Model

  def run(req) do
    org_id = req.metadata.org_id

    with {:ok, n} <- find_by_id_or_name(org_id, req.id, req.name),
         {:ok, _} <- Repo.delete(n) do
      %InternalApi.Notifications.DestroyResponse{
        id: n.id
      }
    else
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
