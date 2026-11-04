defmodule Audit.Retention.QueriesTest do
  use Support.DataCase

  import Ecto.Query

  alias Audit.Event
  alias Audit.Retention.Queries
  alias Support.RetentionFixtures

  describe "mark_expiring/2" do
    test "marks older events and unmarks newer events for a single org" do
      org_id = Ecto.UUID.generate()
      cutoff = DateTime.from_unix!(1_735_603_200)

      older_event =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(cutoff, -86_400, :second)
        })

      newer_event =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(cutoff, 86_400, :second)
        })

      other_org_event =
        RetentionFixtures.insert_event(%{
          org_id: Ecto.UUID.generate(),
          timestamp: DateTime.add(cutoff, -86_400, :second)
        })

      future_expiry =
        DateTime.utc_now()
        |> DateTime.add(7 * 86_400, :second)
        |> DateTime.truncate(:second)

      set_expires_at(newer_event.id, future_expiry)

      {marked, unmarked, :done} = Queries.mark_expiring(org_id, cutoff)

      assert marked == 1
      assert unmarked == 1

      assert_expires_in_about_days(get_event(older_event.id).expires_at, 15)
      assert is_nil(get_event(newer_event.id).expires_at)
      assert is_nil(get_event(other_org_event.id).expires_at)
    end

    test "uses configured grace period" do
      original_config = Application.get_env(:audit, Audit.Retention.Queries, [])
      Application.put_env(:audit, Audit.Retention.Queries, grace_period_days: 30)

      on_exit(fn ->
        Application.put_env(:audit, Audit.Retention.Queries, original_config)
      end)

      org_id = Ecto.UUID.generate()
      cutoff = DateTime.from_unix!(1_735_603_200)

      event =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(cutoff, -86_400, :second)
        })

      {marked, 0, :done} = Queries.mark_expiring(org_id, cutoff)
      assert marked == 1

      assert_expires_in_about_days(get_event(event.id).expires_at, 30)
    end

    test "stops at the time limit and the next call continues" do
      original_config = Application.get_env(:audit, Audit.Retention.Queries, [])
      Application.put_env(:audit, Audit.Retention.Queries, batch_size: 1, time_limit_sec: 0)

      on_exit(fn ->
        Application.put_env(:audit, Audit.Retention.Queries, original_config)
      end)

      org_id = Ecto.UUID.generate()
      cutoff = DateTime.from_unix!(1_735_603_200)

      events =
        for days <- [3, 2] do
          RetentionFixtures.insert_event(%{
            org_id: org_id,
            timestamp: DateTime.add(cutoff, -days * 86_400, :second)
          })
        end

      assert {1, 0, :time_limit} = Queries.mark_expiring(org_id, cutoff)
      assert {1, 0, :time_limit} = Queries.mark_expiring(org_id, cutoff)
      assert {0, 0, :done} = Queries.mark_expiring(org_id, cutoff)

      for event <- events, do: refute(is_nil(get_event(event.id).expires_at))
    end

    test "marks unstreamed events older than cutoff" do
      org_id = Ecto.UUID.generate()
      cutoff = DateTime.from_unix!(1_735_603_200)

      old_unstreamed_event =
        RetentionFixtures.insert_event(%{
          org_id: org_id,
          timestamp: DateTime.add(cutoff, -86_400, :second),
          streamed: false
        })

      {marked, unmarked, :done} = Queries.mark_expiring(org_id, cutoff)

      assert marked == 1
      assert unmarked == 0
      refute is_nil(get_event(old_unstreamed_event.id).expires_at)
    end
  end

  describe "delete_expired_batch/2" do
    test "deletes only expired events up to batch size" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      expired_1 = RetentionFixtures.insert_event(%{expires_at: DateTime.add(now, -600, :second)})
      expired_2 = RetentionFixtures.insert_event(%{expires_at: DateTime.add(now, -300, :second)})
      _future = RetentionFixtures.insert_event(%{expires_at: DateTime.add(now, 300, :second)})
      _no_expiry = RetentionFixtures.insert_event(%{expires_at: nil})

      assert {:ok, %{deleted: 1, unmarked: 0}} = Queries.delete_expired_batch(1, fn _ -> true end)

      remaining_ids = from(e in Event, select: e.id) |> Repo.all()
      refute expired_1.id in remaining_ids
      assert expired_2.id in remaining_ids

      assert {:ok, %{deleted: 1, unmarked: 0}} = Queries.delete_expired_batch(1, fn _ -> true end)
      remaining_ids = from(e in Event, select: e.id) |> Repo.all()
      refute expired_2.id in remaining_ids
    end

    test "unmarks instead of deleting expired events of disabled orgs" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      enabled_org = Ecto.UUID.generate()
      disabled_org = Ecto.UUID.generate()

      enabled_expired =
        RetentionFixtures.insert_event(%{
          org_id: enabled_org,
          expires_at: DateTime.add(now, -600, :second)
        })

      disabled_expired =
        RetentionFixtures.insert_event(%{
          org_id: disabled_org,
          expires_at: DateTime.add(now, -300, :second)
        })

      disabled_not_due =
        RetentionFixtures.insert_event(%{
          org_id: disabled_org,
          expires_at: DateTime.add(now, 300, :second)
        })

      assert {:ok, %{deleted: 1, unmarked: 1}} =
               Queries.delete_expired_batch(10, &(&1 == enabled_org))

      assert is_nil(Repo.get(Event, enabled_expired.id))
      assert is_nil(get_event(disabled_expired.id).expires_at)
      refute is_nil(get_event(disabled_not_due.id).expires_at)
    end
  end

  defp set_expires_at(event_id, expires_at) do
    from(e in Event, where: e.id == ^event_id)
    |> Repo.update_all(set: [expires_at: expires_at])
  end

  defp get_event(event_id), do: Repo.get!(Event, event_id)

  defp assert_expires_in_about_days(expires_at = %DateTime{}, days) do
    expected = DateTime.add(DateTime.utc_now(), days * 86_400, :second)
    diff = abs(DateTime.diff(expires_at, expected, :second))
    assert diff < 60, "Expected expires_at around #{days} days from now, got #{expires_at}"
  end
end
