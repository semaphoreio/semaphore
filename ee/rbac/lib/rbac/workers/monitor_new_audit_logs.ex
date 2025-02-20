defmodule Rbac.Workers.MonitorNewAuditLogs do
  @moduledoc """
    This module periodically checks if there are new entries in the `global_permissions_audit_log`.
    If there are, the worker logs them. We have an alert setup in the GCP to watch for logs starting
    with "[GlobalPermissionsMonitor]", and to forward those logs to a dedicated slack chanel
  """

  alias Rbac.Toolbox.{Periodic, Duration}
  alias Rbac.Repo.GlobalPermissionsAuditLog
  alias Rbac.RoleBindingIdentification, as: RBI
  require Logger

  use Periodic

  def init(_opts) do
    super(%{
      name: "monitor_new_audit_logs_worker",
      naptime: Duration.seconds(10),
      timeout: Duration.seconds(60)
    })
  end

  def perform(_args \\ nil) do
    audit_log = load_req_for_processing()

    if audit_log != nil do
      log_msg = "[GlobalPermissionsMonitor] " <> generate_message(audit_log)
      Logger.info(log_msg)
      mark_log_as_processed(audit_log)
      perform_now()
    end
  end

  defp generate_message(audit_log) do
    user = extract_user_id(audit_log.key) |> Rbac.Store.RbacUser.fetch()

    case [user, audit_log.query_operation] do
      [nil, _] ->
        "User who's id is not recognized was assigned a global permission!!"

      [user, "DELETE"] ->
        "User *#{user.name}* has lost all global permissions"

      [user, operation] when operation in ["INSERT", "UPDATE"] ->
        "User *#{user.name}* has been granted global permissions: #{inspect(audit_log.new_value)}"
    end
  end

  defdelegate extract_user_id(key), to: RBI, as: :extract_user_id_from_cache_key
  defdelegate load_req_for_processing, to: GlobalPermissionsAuditLog, as: :load_unprocessed_logs
  defdelegate mark_log_as_processed(log), to: GlobalPermissionsAuditLog, as: :mark_log_as_notified
end
