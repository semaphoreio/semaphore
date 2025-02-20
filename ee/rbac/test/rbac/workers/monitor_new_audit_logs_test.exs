defmodule Rbac.Workers.MonitorNewAuditLogsTest do
  use Rbac.RepoCase, async: false

  import ExUnit.CaptureLog
  alias Rbac.Workers.MonitorNewAuditLogs, as: Worker
  alias Rbac.Repo

  @user_id Ecto.UUID.generate()
  @name "Shawn Crowder"
  @worker_sleep_time 10_000

  setup do
    {:ok, worker} = Worker.start_link()
    on_exit(fn -> Process.exit(worker, :kill) end)

    Support.Factories.RbacUser.insert(@user_id, @name)

    :ok
  end

  describe "perform\1" do
    test "When a new user gets global permissions" do
      key = "user:#{@user_id}_org:*_project:*"
      permissions = "organization.view"

      insert_global_permissions(key, permissions)

      log =
        capture_log(fn ->
          audit_log = get_audit_log()

          assert audit_log.key == key
          assert audit_log.new_value == permissions
          assert audit_log.query_operation == "INSERT"
          refute audit_log.notified

          :timer.sleep(@worker_sleep_time + 3_000)

          audit_log = get_audit_log()
          assert audit_log.notified
        end)

      assert log =~
               "[GlobalPermissionsMonitor] User *#{@name}* has been granted global permissions: \"#{permissions}\""
    end

    test "When a new user loses global permissions" do
      key = "user:#{@user_id}_org:*_project:*"

      insert_global_permissions(key, "organization.view")
      clear_previous_audit_logs()

      log =
        capture_log(fn ->
          delete_global_permissions()
          audit_log = get_audit_log()

          assert audit_log.key == key
          assert audit_log.new_value == ""
          assert audit_log.query_operation == "DELETE"
          refute audit_log.notified

          :timer.sleep(@worker_sleep_time + 3_000)

          audit_log = get_audit_log()
          assert audit_log.notified
        end)

      assert log =~ "[GlobalPermissionsMonitor] User *#{@name}* has lost all global permissions"
    end

    test "When user's global permissions are modified" do
      key = "user:#{@user_id}_org:*_project:*"
      old_permissions = "organization.view"
      new_permissions = "organization.people.manage"

      insert_global_permissions(key, old_permissions)
      clear_previous_audit_logs()

      log =
        capture_log(fn ->
          insert_global_permissions(key, new_permissions)

          audit_log = get_audit_log()

          assert audit_log.key == key
          assert audit_log.new_value == new_permissions
          assert audit_log.query_operation == "UPDATE"
          refute audit_log.notified

          :timer.sleep(@worker_sleep_time + 3_000)

          audit_log = get_audit_log()
          assert audit_log.notified
        end)

      assert log =~
               "[GlobalPermissionsMonitor] User *#{@name}* has been granted global permissions: \"#{new_permissions}\""
    end
  end

  defp clear_previous_audit_logs, do: Repo.GlobalPermissionsAuditLog |> Repo.delete_all()
  defp delete_global_permissions, do: Repo.UserPermissionsKeyValueStore |> Repo.delete_all()
  defp get_audit_log, do: Repo.GlobalPermissionsAuditLog |> Repo.one()

  defp insert_global_permissions(key, permissions) do
    %Repo.UserPermissionsKeyValueStore{key: key, value: permissions}
    |> Repo.insert(on_conflict: {:replace, [:updated_at, :value]}, conflict_target: [:key])
  end
end
