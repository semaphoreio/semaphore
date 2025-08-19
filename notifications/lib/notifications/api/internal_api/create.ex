defmodule Notifications.Api.InternalApi.Create do
  require Logger

  alias Notifications.{Repo, Models}

  alias Notifications.Api.InternalApi.Serialization
  alias Notifications.Util.Validator
  alias InternalApi.Notifications.CreateResponse

  def run(req) do
    IO.puts("REQ RUN")
    IO.inspect(req.metadata)
    IO.inspect(req)

    org_id = req.metadata.org_id

    with {:ok, :valid} <- Validator.validate(req.notification),
         {:ok, n} <- create_notification(org_id, req.notification) do
      %CreateResponse{notification: Serialization.serialize(n)}
    else
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

  defp create_notification(org_id, notification) do
    Repo.transaction(fn ->
      n =
        Models.Notification.new(
          org_id,
          notification.name,
          Notifications.Util.Transforms.encode_spec(%{rules: notification.rules})
        )

      case Repo.insert(n) do
        {:ok, n} ->
          :ok = Notifications.Util.RuleFactory.persist_rules(n, notification.rules)
          n

        {:error, changeset} ->
          {:failed_precondition, parse_error_msg(changeset.errors)}
          |> Repo.rollback()
      end
    end)
  end

  defp parse_error_msg([{:unique_names, {message, _}} | _]), do: message
end
