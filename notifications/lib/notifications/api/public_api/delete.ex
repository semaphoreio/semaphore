defmodule Notifications.Api.PublicApi.Delete do
  require Logger

  alias Notifications.{Auth, Repo, Models}
  alias Models.Notification, as: Model
  alias Semaphore.Notifications.V1alpha.Empty

  def run(req, org_id, user_id) do
    name_or_id = req.notification_id_or_name

    Logger.info("#{inspect(org_id)} #{inspect(user_id)} #{name_or_id}")

    with {:ok, :authorized} <- Auth.can_manage?(user_id, org_id),
         {:ok, n} <- Model.find_by_id_or_name(org_id, name_or_id),
         {:ok, _} <- Repo.delete(n) do
      Empty.new()
    else
      {:error, :permission_denied} ->
        raise_error!(:not_found, "Notification #{name_or_id} not found")

      {:error, :not_found} ->
        raise_error!(:not_found, "Notification #{name_or_id} not found")

      {:error, :invalid_argument, message} ->
        raise_error!(:invalid_argument, message)

      {:error, message} ->
        raise_error!(:unknown, message)
    end
  end

  def raise_error!(status, message) do
    raise GRPC.RPCError, status: status, message: message
  end
end
