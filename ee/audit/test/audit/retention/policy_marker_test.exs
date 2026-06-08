defmodule Audit.Retention.PolicyMarkerTest do
  use Support.DataCase

  alias Audit.Event
  alias Audit.Retention.PolicyMarker
  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Support.RetentionFixtures

  test "marks old events and keeps recent events" do
    org_id = Ecto.UUID.generate()
    # Older than the 400-day retention floor so the cutoff is accepted.
    cutoff =
      DateTime.add(DateTime.utc_now(), -401 * 86_400, :second) |> DateTime.truncate(:second)

    old_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(cutoff, -120, :second)
      })

    recent_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(cutoff, 120, :second)
      })

    other_org =
      RetentionFixtures.insert_event(%{
        org_id: Ecto.UUID.generate(),
        timestamp: DateTime.add(cutoff, -120, :second)
      })

    PolicyMarker.handle_message(encode_policy_event(org_id, cutoff))

    refute is_nil(get_event(old_event.id).expires_at)
    assert is_nil(get_event(recent_event.id).expires_at)
    assert is_nil(get_event(other_org.id).expires_at)
  end

  test "ignores invalid org id payload" do
    org_id = Ecto.UUID.generate()
    cutoff = DateTime.from_unix!(1_735_603_200)

    old_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(cutoff, -120, :second)
      })

    assert :ok = PolicyMarker.handle_message(encode_policy_event("not-a-uuid", cutoff))
    assert is_nil(get_event(old_event.id).expires_at)
  end

  test "ignores policy event with zero-value cutoff" do
    org_id = Ecto.UUID.generate()
    cutoff = DateTime.from_unix!(1_735_603_200)

    old_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(cutoff, -120, :second)
      })

    message =
      %OrganizationPolicyApply{
        org_id: org_id,
        cutoff_date: %Timestamp{seconds: 0, nanos: 0}
      }
      |> OrganizationPolicyApply.encode()

    assert :ok = PolicyMarker.handle_message(message)
    assert is_nil(get_event(old_event.id).expires_at)
  end

  test "ignores policy event with future cutoff" do
    org_id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    old_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(now, -120, :second)
      })

    future_cutoff = DateTime.add(now, 3_600, :second)

    assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, future_cutoff))
    assert is_nil(get_event(old_event.id).expires_at)
  end

  test "refuses cutoff more recent than the retention floor" do
    org_id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # A cutoff well inside the 400-day floor would expire recent audit logs.
    too_recent_cutoff = DateTime.add(now, -10 * 86_400, :second)

    old_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(too_recent_cutoff, -120, :second)
      })

    assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, too_recent_cutoff))
    assert is_nil(get_event(old_event.id).expires_at)
  end

  test "clamps a configured floor below the policy up to the 400-day minimum" do
    with_min_retention_days(30, fn ->
      org_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # 60 days old: would pass the requested 30-day floor, but the floor cannot
      # be weakened below the 400-day policy, so it is refused.
      cutoff = DateTime.add(now, -60 * 86_400, :second)

      old_event =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(cutoff, -120, :second)
        })

      assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, cutoff))
      assert is_nil(get_event(old_event.id).expires_at)
    end)
  end

  test "honors a stricter (larger) configured floor" do
    with_min_retention_days(800, fn ->
      org_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # 500 days old: fine under the default 400-day floor, but refused under the
      # configured stricter 800-day floor.
      cutoff = DateTime.add(now, -500 * 86_400, :second)

      old_event =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(cutoff, -120, :second)
        })

      assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, cutoff))
      assert is_nil(get_event(old_event.id).expires_at)
    end)
  end

  defp with_min_retention_days(days, fun) do
    original_config = Application.get_env(:audit, PolicyMarker, [])

    Application.put_env(
      :audit,
      PolicyMarker,
      Keyword.put(original_config, :min_retention_days, days)
    )

    try do
      fun.()
    after
      Application.put_env(:audit, PolicyMarker, original_config)
    end
  end

  defp encode_policy_event(org_id, cutoff) do
    RetentionFixtures.encode_policy_event(org_id, cutoff)
  end

  defp get_event(event_id), do: Repo.get!(Event, event_id)
end
