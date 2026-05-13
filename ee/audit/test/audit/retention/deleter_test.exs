defmodule Audit.Retention.DeleterTest do
  use Support.DataCase

  import Ecto.Query

  alias Audit.Event
  alias Audit.Retention.Deleter
  alias Audit.Retention.PolicyMarker
  alias Support.RetentionFixtures

  test "deletes only expired events for org that received retention policy event" do
    cutoff = DateTime.utc_now() |> DateTime.truncate(:second)
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
      Deleter.handle_info(:tick, %{batch_size: 100, interval_ms: 60_000, backlog_tick: 0})

    refute event_exists?(old_event_with_policy.id)
    assert event_exists?(new_event_with_policy.id)
    assert event_exists?(old_event_without_policy.id)
    assert event_exists?(new_event_without_policy.id)
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
