defmodule Audit.Retention.PolicyMarkerTest do
  use Support.DataCase

  alias Audit.Event
  alias Audit.Retention.PolicyMarker
  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Support.RetentionFixtures

  setup do
    stub_retention_feature(true)
    :ok
  end

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

  test "skips marking when the audit_logs_retention feature is disabled" do
    stub_retention_feature(false)

    org_id = Ecto.UUID.generate()

    cutoff =
      DateTime.add(DateTime.utc_now(), -401 * 86_400, :second) |> DateTime.truncate(:second)

    old_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(cutoff, -120, :second)
      })

    assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, cutoff))
    assert is_nil(get_event(old_event.id).expires_at)
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

  test "clamps a future cutoff to the retention floor" do
    org_id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future_cutoff = DateTime.add(now, 3_600, :second)

    # Older than the 400-day floor: still expired (clamped, not dropped).
    beyond_floor =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(now, -420 * 86_400, :second)
      })

    # Recent: never expired, even though the cutoff is in the future.
    recent =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(now, -120, :second)
      })

    assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, future_cutoff))
    refute is_nil(get_event(beyond_floor.id).expires_at)
    assert is_nil(get_event(recent.id).expires_at)
  end

  test "clamps a too-recent cutoff to the retention floor" do
    org_id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Publisher asks for a 10-day window — far inside the 400-day floor.
    too_recent_cutoff = DateTime.add(now, -10 * 86_400, :second)

    # Older than the floor: must still be marked (we clamp instead of dropping).
    beyond_floor =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(now, -420 * 86_400, :second)
      })

    # Within the floor: kept, even though the requested 10-day window would
    # have expired it.
    within_floor =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(now, -200 * 86_400, :second)
      })

    assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, too_recent_cutoff))
    refute is_nil(get_event(beyond_floor.id).expires_at)
    assert is_nil(get_event(within_floor.id).expires_at)
  end

  test "a configured floor below the policy is clamped up to the 400-day minimum" do
    with_min_retention_days(30, fn ->
      org_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Both the publisher window (60d) and the configured floor (30d) are below
      # the 400-day policy minimum, so retention still floors at 400 days.
      cutoff = DateTime.add(now, -60 * 86_400, :second)

      beyond_floor =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(now, -420 * 86_400, :second)
        })

      within_floor =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(now, -90 * 86_400, :second)
        })

      assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, cutoff))
      refute is_nil(get_event(beyond_floor.id).expires_at)
      assert is_nil(get_event(within_floor.id).expires_at)
    end)
  end

  test "honors a stricter (larger) configured floor" do
    with_min_retention_days(800, fn ->
      org_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # 500-day window is fine under the default 400-day floor, but the stricter
      # 800-day floor clamps it: 500-day-old events are kept, only 800d+ expire.
      cutoff = DateTime.add(now, -500 * 86_400, :second)

      beyond_floor =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(now, -820 * 86_400, :second)
        })

      within_floor =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(now, -500 * 86_400, :second)
        })

      assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, cutoff))
      refute is_nil(get_event(beyond_floor.id).expires_at)
      assert is_nil(get_event(within_floor.id).expires_at)
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
