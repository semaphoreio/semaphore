defmodule Audit.Retention.DeleterTest do
  use Support.DataCase

  import Ecto.Query

  alias Audit.Event
  alias Audit.Retention.Deleter
  alias Audit.Retention.PolicyMarker
  alias Support.RetentionFixtures

  test "deletes only expired events for org that received retention policy event" do
    # The org must have the retention feature enabled for the policy to be applied.
    stub_retention_feature(true)

    # Older than the 400-day retention floor so the policy cutoff is accepted.
    cutoff =
      DateTime.add(DateTime.utc_now(), -401 * 86_400, :second) |> DateTime.truncate(:second)

    org_with_policy = Ecto.UUID.generate()
    org_without_policy = Ecto.UUID.generate()

    old_event_with_policy =
      RetentionFixtures.insert_event(%{
        org_id: org_with_policy,
        timestamp: DateTime.add(cutoff, -30 * 86_400, :second)
      })

    new_event_with_policy =
      RetentionFixtures.insert_event(%{
        org_id: org_with_policy,
        timestamp: DateTime.add(cutoff, 30 * 86_400, :second)
      })

    old_event_without_policy =
      RetentionFixtures.insert_event(%{
        org_id: org_without_policy,
        timestamp: DateTime.add(cutoff, -30 * 86_400, :second)
      })

    new_event_without_policy =
      RetentionFixtures.insert_event(%{
        org_id: org_without_policy,
        timestamp: DateTime.add(cutoff, 30 * 86_400, :second)
      })

    PolicyMarker.handle_message(RetentionFixtures.encode_policy_event(org_with_policy, cutoff))

    assert_marked(old_event_with_policy.id)
    assert_unmarked(new_event_with_policy.id)
    assert_unmarked(old_event_without_policy.id)
    assert_unmarked(new_event_without_policy.id)

    force_expiration(old_event_with_policy.id)

    {:noreply, _state} =
      Deleter.handle_info(:tick, %{
        batch_size: 100,
        idle_interval_ms: 60_000,
        drain_interval_ms: 1_000,
        backlog_tick: 0
      })

    refute event_exists?(old_event_with_policy.id)
    assert event_exists?(new_event_with_policy.id)
    assert event_exists?(old_event_without_policy.id)
    assert event_exists?(new_event_without_policy.id)
  end

  test "drains quickly after a full batch and backs off once caught up" do
    past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

    # handle_info schedules :tick to the caller; here that is the test process,
    # so we can observe which cadence it picks via the timer.
    RetentionFixtures.insert_event(%{expires_at: past})
    RetentionFixtures.insert_event(%{expires_at: past})

    # batch_size 1 with 2 expired rows -> first tick deletes a full batch ->
    # short drain interval -> :tick arrives well within the window.
    drain_state = %{
      batch_size: 1,
      idle_interval_ms: 60_000,
      drain_interval_ms: 20,
      backlog_tick: 0
    }

    {:noreply, _} = Deleter.handle_info(:tick, drain_state)
    assert_receive :tick, 2_000

    # One expired row left, batch_size 5 -> partial batch -> long idle interval ->
    # no :tick within the window.
    idle_state = %{
      batch_size: 5,
      idle_interval_ms: 60_000,
      drain_interval_ms: 20,
      backlog_tick: 0
    }

    {:noreply, _} = Deleter.handle_info(:tick, idle_state)
    refute_receive :tick, 300
  end

  defp assert_marked(event_id) do
    refute is_nil(get_event(event_id).expires_at)
  end

  defp assert_unmarked(event_id) do
    assert is_nil(get_event(event_id).expires_at)
  end

  defp force_expiration(event_id) do
    expired_at =
      DateTime.utc_now()
      |> DateTime.add(-5, :second)
      |> DateTime.truncate(:second)

    from(e in Event, where: e.id == ^event_id)
    |> Repo.update_all(set: [expires_at: expired_at])
  end

  defp event_exists?(event_id), do: Repo.get(Event, event_id) != nil
  defp get_event(event_id), do: Repo.get!(Event, event_id)
end
