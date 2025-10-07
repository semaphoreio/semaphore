defmodule Notifications.Api.PublicApi.Create do
  require Logger

  alias Notifications.{Auth, Repo, Models}

  alias Notifications.Api.PublicApi.Serialization
  alias Notifications.Util.Validator

  def run(notification, org_id, user_id) do
    name = notification.metadata.name

    Logger.info("#{inspect(org_id)} #{inspect(user_id)} #{name}")

    with {:ok, :authorized} <- Auth.can_manage?(user_id, org_id),
         {:ok, :valid} <- Validator.validate(notification, user_id),
         {:ok, n} <- create_notification(org_id, user_id, notification) do
      Serialization.serialize(n)
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "You are not authorized to create notifications"

      {:error, :invalid_argument, message} ->
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: message

      {:error, {status, message}} ->
        raise GRPC.RPCError, status: status, message: message

      {:error, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def create_notification(org_id, creator_id, notification) do
    Repo.transaction(fn ->
      n =
        Models.Notification.new(
          org_id,
          notification.metadata.name,
          creator_id,
          Notifications.Util.Transforms.encode_spec(notification.spec)
        )

      case Repo.insert(n) do
        {:ok, n} ->
          :ok = Notifications.Util.RuleFactory.persist_rules(n, notification.spec.rules)

          n

        {:error, changeset} ->
          Logger

          {:failed_precondition, parse_error_msg(changeset.errors)}
          |> Repo.rollback()
      end
    end)
  end

  defp parse_error_msg([{:unique_names, {message, _}} | _]), do: message
end
