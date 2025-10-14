defmodule Rbac.Workers.SyncOidcUsers do
  @moduledoc """
    This module periodically if there are any users in the database that does not have a OIDC connection
    For every user found - it creates a OIDC user and connects it to the user.
    Only works when OIDC is enabled
  """

  @type worker_args :: [
          # Number of users to process. If set to :unlimited, all users will be processed.
          users_to_process: non_neg_integer() | :unlimited,
          # Number of users to process per batch.
          users_per_batch: non_neg_integer()
        ]

  require(Logger)

  alias Rbac.Toolbox.{Periodic, Duration}
  alias Rbac.Store.RbacUser
  use Periodic

  def init(_opts) do
    super(%{
      name: "sync_oidc_users_worker",
      naptime: Duration.seconds(60),
      timeout: Duration.seconds(60 * 5)
    })
  end

  @spec perform(args :: worker_args()) :: any
  def perform(args \\ []) do
    users_to_process = Keyword.get(args, :users_to_process, :unlimited)
    users_per_batch = Keyword.get(args, :users_per_batch, 1000)

    if Rbac.OIDC.enabled?() do
      Logger.info("[SyncOidcUsers Worker] Syncing OIDC users")

      results =
        stream_users_without_oidc_connection(users_per_batch)
        |> case do
          stream when users_to_process != :unlimited ->
            stream
            |> Stream.take(users_to_process)

          stream ->
            stream
        end
        |> Stream.chunk_every(users_per_batch)
        |> Stream.flat_map(fn users ->
          Logger.info("[SyncOidcUsers Worker] Processing #{length(users)} users")

          connect_oidc_users(users)
        end)
        |> Enum.to_list()

      not_connected_users =
        results
        |> Enum.filter(fn
          {:error, _} -> true
          _ -> false
        end)

      Logger.info(
        "[SyncOidcUsers Worker] Synced #{length(results) - length(not_connected_users)} users"
      )

      not_connected_users
    end
  end

  @spec stream_users_without_oidc_connection(non_neg_integer()) :: Stream.t()
  defp stream_users_without_oidc_connection(limit) do
    Stream.unfold(
      RbacUser.fetch_users_without_oidc_connection(1, limit),
      fn
        {_page, []} ->
          nil

        {page, _users_without_connection} = result ->
          {result, RbacUser.fetch_users_without_oidc_connection(page + 1, limit)}
      end
    )
    |> Stream.flat_map(fn {_page, users} -> users end)
  end

  @spec connect_oidc_users([RbacUser.t()]) :: [RbacUser.t()]
  defp connect_oidc_users(users_without_connection) do
    {:ok, client} = Rbac.Api.OIDC.client()

    users_without_connection
    |> Enum.map(fn user ->
      connect_oidc_user(client, user)
    end)
  end

  @spec connect_oidc_user(Rbac.Api.OIDC.client(), RbacUser.t()) :: RbacUser.t() | {:error, any()}
  defp connect_oidc_user(client, user) do
    with {:ok, oidc_user_id} <- Rbac.Api.OIDC.create_oidc_user(client, user),
         {:ok, connected_user} <- Rbac.Store.OIDCUser.connect_user(oidc_user_id, user.id) do
      connected_user
    else
      {:error, e} ->
        Logger.error("[SyncOidcUsers Worker] Error when creating OIDC user: #{inspect(e)}")
        {:error, {user, e}}
    end
  end
end
