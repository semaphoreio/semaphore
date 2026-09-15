defmodule Guard.FederatedIdentitySyncDrainer do
  @moduledoc """
  Retries Keycloak federated-identity syncs whose outbox rows are still
  pending: syncs that failed past their in-process retries, or whose task was
  lost to a restart between the claim commit and completion.

  Rows are leased atomically (SKIP LOCKED plus a `next_attempt_at` bump), so
  concurrent drainer runs never double-process a row. A fully synced row is
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
      requests = FederatedIdentitySyncRequest.lease_due(@batch_size)

      if requests != [] do
        Logger.info("[FederatedIdentitySyncDrainer] Retrying #{length(requests)} pending sync(s)")
      end

      Enum.each(requests, &Guard.OIDC.FederatedIdentitySync.run_request/1)

      Watchman.submit(@pending_metric, FederatedIdentitySyncRequest.pending_count())

      :ok
    end)
  end
end
