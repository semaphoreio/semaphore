defmodule Guard.ServiceAccount.OwnerBackfill do
  @moduledoc """
  Gives an owner to service accounts that were never given one.

  An account made before owners were recorded has none, and its creator is the one
  person the organization already named for it, so they become the owner while they are
  still an active member. Accounts no member stands behind keep none, and so does an
  account that lost the owner it was given, since that was decided once already.
  """

  use Quantum, otp_app: :guard

  alias Guard.Store.ServiceAccount

  require Logger

  def process do
    Watchman.benchmark("guard.service_account_owner_backfill", fn ->
      Logger.info("Starting service account owner backfill")

      assigned = ServiceAccount.backfill_owners()

      Logger.info("Finished service account owner backfill, gave an owner to #{assigned}")
      :ok
    end)
  end
end
