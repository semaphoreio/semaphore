defmodule Notifications.Api.PublicApi.Get do
  require Logger

  alias Notifications.{Auth, Models}
  alias Notifications.Api.PublicApi.Serialization
  alias Models.Notification, as: Model

  def run(req, org_id, user_id) do
    name_or_id = req.notification_id_or_name

    Logger.info("#{inspect(org_id)} #{inspect(user_id)} #{name_or_id}")

    with {:ok, :authorized} <- Auth.can_view?(user_id, org_id),
         {:ok, n} <- Model.find_by_id_or_name(org_id, name_or_id) do
      Serialization.serialize(n)
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "Notification #{name_or_id} not found"

      {:error, :not_found} ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "Notification #{name_or_id} not found"

      {:error, :invalid_argument, message} ->
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: message

      {:error, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end
end
