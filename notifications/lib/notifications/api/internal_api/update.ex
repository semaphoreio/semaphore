defmodule Notifications.Api.InternalApi.Update do
  require Logger

  alias Notifications.{Repo, Models}
  alias Notifications.Api.InternalApi.Serialization
  alias Models.Notification, as: Model
  alias Notifications.Util.Validator
  alias InternalApi.Notifications.UpdateResponse

  def run(req) do
    org_id = req.metadata.org_id
    updater_id = req.metadata.user_id

    with {:ok, :valid} <- Validator.validate(req.notification, updater_id),
         {:ok, n} <- find_by_id_or_name(org_id, req.id, req.name),
         {:ok, n} <- update_notification(n, updater_id, req.notification) do
      %UpdateResponse{notification: Serialization.serialize(n)}
    else
      {:error, :invalid_argument, message} ->
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: message

      {:error, :not_found} ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "Notification not found"

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
  defp update_notification(notification, updater_id, apiresource) do
    Repo.transaction(fn ->
      changes =
        Model.changeset(notification, %{
          name: apiresource.name,
          creator_id: updater_id,
          spec: Notifications.Util.Transforms.encode_spec(%{rules: apiresource.rules})
        })

      case Repo.update(changes) do
        {:ok, n} ->
          # First, we delete all existing rules
          n = Repo.preload(n, :rules)
          n.rules |> Enum.each(fn r -> Repo.delete(r) end)
          # Then, we recreate the rules based on the API resource
          :ok = Notifications.Util.RuleFactory.persist_rules(n, apiresource.rules)
          n

        {:error, changeset} ->
          {:failed_precondition, parse_error_msg(changeset.errors)}
          |> Repo.rollback()
      end
    end)
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

  defp parse_error_msg([{:unique_names, {message, _}} | _]), do: message
end
