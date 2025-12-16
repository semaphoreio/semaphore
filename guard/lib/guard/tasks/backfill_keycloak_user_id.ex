defmodule Guard.Tasks.BackfillKeycloakUserId do
  @moduledoc """
  Task to backfill semaphore_user_id attribute in Keycloak for existing users.

  This is needed for MCP OAuth 2.1 support, where the semaphore_user_id claim
  is added to JWT tokens via a Keycloak attribute mapper.

  ## Usage

  Run from IEx:

      Guard.Tasks.BackfillKeycloakUserId.run()

  Or with options:

      Guard.Tasks.BackfillKeycloakUserId.run(batch_size: 100, dry_run: true)

  ## Options

  * `:batch_size` - Number of users to process at a time (default: 50)
  * `:dry_run` - If true, only log what would be done without making changes (default: false)
  * `:delay_ms` - Delay between batches in milliseconds (default: 1000)
  """

  require Logger

  @default_batch_size 50
  @default_delay_ms 1000

  def run(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    dry_run = Keyword.get(opts, :dry_run, false)
    delay_ms = Keyword.get(opts, :delay_ms, @default_delay_ms)

    Logger.info("[BackfillKeycloakUserId] Starting backfill (dry_run: #{dry_run})")

    {:ok, client} = Guard.Api.OIDC.client()

    # Get all OIDC users from the database
    users = list_all_oidc_users()

    total = length(users)
    Logger.info("[BackfillKeycloakUserId] Found #{total} users to process")

    users
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, batch_index} ->
      process_batch(client, batch, batch_index, batch_size, total, dry_run)

      if not dry_run and batch_index < div(total, batch_size) do
        Process.sleep(delay_ms)
      end
    end)

    Logger.info("[BackfillKeycloakUserId] Backfill complete")
    :ok
  end

  defp list_all_oidc_users do
    # Query oidc_users table joined with rbac_users to get both IDs
    import Ecto.Query

    query =
      from(ou in Guard.Repo.OidcUser,
        join: ru in Guard.Repo.RbacUser,
        on: ou.user_id == ru.id,
        select: %{
          oidc_user_id: ou.oidc_user_id,
          semaphore_user_id: ru.id
        }
      )

    Guard.Repo.all(query)
  end

  defp process_batch(client, batch, batch_index, batch_size, total, dry_run) do
    start = batch_index * batch_size + 1
    finish = min(start + length(batch) - 1, total)

    Logger.info("[BackfillKeycloakUserId] Processing users #{start}-#{finish} of #{total}")

    Enum.each(batch, fn user ->
      if dry_run do
        Logger.info(
          "[BackfillKeycloakUserId] [DRY RUN] Would set semaphore_user_id=#{user.semaphore_user_id} for Keycloak user #{user.oidc_user_id}"
        )
      else
        case Guard.Api.OIDC.set_user_attribute(
               client,
               user.oidc_user_id,
               "semaphore_user_id",
               user.semaphore_user_id
             ) do
          {:ok, _} ->
            Logger.debug(
              "[BackfillKeycloakUserId] Set semaphore_user_id for Keycloak user #{user.oidc_user_id}"
            )

          {:error, error} ->
            Logger.error(
              "[BackfillKeycloakUserId] Failed to set semaphore_user_id for Keycloak user #{user.oidc_user_id}: #{inspect(error)}"
            )
        end
      end
    end)
  end
end
