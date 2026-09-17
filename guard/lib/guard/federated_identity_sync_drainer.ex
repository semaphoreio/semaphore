defmodule Guard.FederatedIdentitySyncDrainer do
  @moduledoc """
  Retries Keycloak federated-identity syncs whose outbox rows are still
  pending: syncs that failed past their in-process retries, or whose task was
  lost to a restart between the claim commit and completion.

  Rows are leased one at a time, immediately before processing (a conditional
  `next_attempt_at` bump), so concurrent drainer runs never double-process a
  row and a slow row cannot expire the lease of one still queued behind it.
  A fully synced row is
  deleted; failures reschedule with exponential backoff. The pending volume
  is emitted as a gauge so stuck syncs surface instead of rotting silently.
  """

  use Quantum, otp_app: :guard

  require Logger

  alias Guard.FrontRepo.FederatedIdentitySyncRequest

  @batch_size 50
  @pending_metric "guard.federated_identity_sync.pending"

  @spec process() :: :ok
  def process do
    if Guard.OIDC.enabled?() do
      drain()
    else
      :ok
    end
  end

  defp drain do
    Watchman.benchmark("guard.federated_identity_sync_drainer", fn ->
      due = FederatedIdentitySyncRequest.due_ids(@batch_size)

      if due != [] do
        Logger.info("[FederatedIdentitySyncDrainer] Retrying #{length(due)} pending sync(s)")
      end

      # Leased one row at a time, immediately before processing it, so the
      # lease window only has to cover a single row. Rows another drainer took
      # in the meantime come back nil and are skipped.
      Enum.each(due, fn id ->
        case FederatedIdentitySyncRequest.lease(id) do
          nil -> :ok
          request -> Guard.OIDC.FederatedIdentitySync.run_request(request)
        end
      end)

      Watchman.submit(@pending_metric, FederatedIdentitySyncRequest.pending_count())

      :ok
    end)
  end
end
