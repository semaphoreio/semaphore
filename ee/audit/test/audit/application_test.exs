defmodule Audit.ApplicationTest do
  use ExUnit.Case, async: false

  setup do
    original_policy = Application.get_env(:audit, Audit.Retention.PolicyMarker, [])
    original_deleter = Application.get_env(:audit, Audit.Retention.Deleter, [])

    on_exit(fn ->
      Application.put_env(:audit, Audit.Retention.PolicyMarker, original_policy)
      Application.put_env(:audit, Audit.Retention.Deleter, original_deleter)
    end)

    :ok
  end

  test "starts marker without deleter when only policy is enabled" do
    Application.put_env(:audit, Audit.Retention.PolicyMarker, enabled: true)
    Application.put_env(:audit, Audit.Retention.Deleter, enabled: false)

    assert [Audit.Retention.PolicyMarker] == Audit.Application.retention_worker_children()
  end

  test "starts deleter without marker when only deleter is enabled" do
    Application.put_env(:audit, Audit.Retention.PolicyMarker, enabled: false)
    Application.put_env(:audit, Audit.Retention.Deleter, enabled: true)

    assert [Audit.Retention.Deleter] == Audit.Application.retention_worker_children()
  end

  test "starts both workers when both are enabled" do
    Application.put_env(:audit, Audit.Retention.PolicyMarker, enabled: true)
    Application.put_env(:audit, Audit.Retention.Deleter, enabled: true)

    assert [Audit.Retention.PolicyMarker, Audit.Retention.Deleter] ==
             Audit.Application.retention_worker_children()
  end
end
