defmodule Notifications.Api.PublicApi.Update do
  require Logger

  alias Notifications.{Auth, Repo, Models}
  alias Notifications.Api.PublicApi.Serialization
  alias Notifications.Util.Validator
  alias Models.Notification, as: Model

  def run(req, org_id, user_id) do
    name_or_id = req.notification_id_or_name

    Logger.info("#{inspect(org_id)} #{inspect(user_id)} #{name_or_id}")

    with {:ok, :authorized} <- Auth.can_manage?(user_id, org_id),
         {:ok, :valid} <- Validator.validate(req.notification, user_id),
         {:ok, n} <- Model.find_by_id_or_name(org_id, name_or_id),
         {:ok, n} <- update_notification(n, user_id, req.notification) do
      Serialization.serialize(n)
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "Notification #{name_or_id} not found"

      {:error, :invalid_argument, message} ->
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: message

      {:error, :not_found} ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "Notification #{name_or_id} not found"

      {:error, {status, message}} ->
        raise GRPC.RPCError, status: status, message: message

      {:error, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  #
  # notification: existing row from database
  # apiresource: new notification from the API call that needs to be applied
  #
  def update_notification(notification, creator_id, apiresource) do
    Repo.transaction(fn ->
      changes =
        Model.changeset(notification, %{
          name: apiresource.metadata.name,
          creator_id: creator_id,
          spec: Notifications.Util.Transforms.encode_spec(apiresource.spec)
        })

      case Repo.update(changes) do
        {:ok, n} ->
          # First, we delete all existing rules
          n = Repo.preload(n, :rules)
          n.rules |> Enum.each(fn r -> Repo.delete(r) end)
          # Then, we recreate the rules based on the API resource
          :ok = Notifications.Util.RuleFactory.persist_rules(n, apiresource.spec.rules)
          n

        {:error, changeset} ->
          {:failed_precondition, parse_error_msg(changeset.errors)}
          |> Repo.rollback()
      end
    end)
  end

  defp parse_error_msg([{:unique_names, {message, _}} | _]), do: message
end
