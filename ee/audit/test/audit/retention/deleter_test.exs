defmodule Audit.Retention.DeleterTest do
  use Support.DataCase

  import Ecto.Query

  alias Audit.Event
  alias Audit.FeatureProviderInvalidatorWorker
  alias Audit.Retention
  alias Audit.Retention.Deleter
  alias Audit.Retention.PolicyMarker
  alias InternalApi.Feature.OrganizationFeaturesChanged
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

    tick()

    refute event_exists?(old_event_with_policy.id)
    assert event_exists?(new_event_with_policy.id)
    assert event_exists?(old_event_without_policy.id)
    assert event_exists?(new_event_without_policy.id)
  end

  test "keeps and unmarks already marked events once the feature is turned off" do
    stub_retention_feature(false)

    marked_event = insert_expired_event(500)

    tick()

    assert event_exists?(marked_event.id)
    assert_unmarked(marked_event.id)
  end

  test "keeps and unmarks expired events when the feature lookup fails" do
    stub_failing_feature_service()

    marked_event = insert_expired_event(500)

    tick()

    assert event_exists?(marked_event.id)
    assert_unmarked(marked_event.id)
  end

  test "stops deleting once the organization's feature change event arrives" do
    marked_event = insert_expired_event(500)
    org_id = marked_event.org_id

    stub_retention_feature(true)
    assert Retention.enabled?(org_id)

    stub_retention_feature(false)
    organization_features_changed(org_id)

    tick()

    assert event_exists?(marked_event.id)
    assert_unmarked(marked_event.id)
  end

  test "keeps expired events younger than a raised retention floor" do
    stub_retention_feature(true)
    put_min_retention_days(800)

    # Both were marked under the 400-day floor.
    within_floor = insert_expired_event(500)
    beyond_floor = insert_expired_event(900)

    tick()

    assert event_exists?(within_floor.id)
    assert_unmarked(within_floor.id)
    refute event_exists?(beyond_floor.id)
  end

  test "drains quickly after a full batch and backs off once caught up" do
    stub_retention_feature(true)

    # handle_info schedules :tick to the caller; here that is the test process,
    # so we can observe which cadence it picks via the timer.
    insert_expired_event(500)
    insert_expired_event(500)

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

  defp tick do
    {:noreply, _state} =
      Deleter.handle_info(:tick, %{
        batch_size: 100,
        idle_interval_ms: 60_000,
        drain_interval_ms: 1_000,
        backlog_tick: 0
      })
  end

  # An event `age_days` old whose grace period ended a minute ago.
  defp insert_expired_event(age_days) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    RetentionFixtures.insert_event(%{
      timestamp: DateTime.add(now, -age_days * 86_400, :second),
      expires_at: DateTime.add(now, -60, :second)
    })
  end

  defp organization_features_changed(org_id) do
    [org_id: org_id]
    |> OrganizationFeaturesChanged.new()
    |> OrganizationFeaturesChanged.encode()
    |> FeatureProviderInvalidatorWorker.organization_features_changed()
  end

  defp put_min_retention_days(days) do
    original_config = Application.get_env(:audit, Retention, [])
    config = Keyword.put(original_config, :min_retention_days, days)
    Application.put_env(:audit, Retention, config)
    on_exit(fn -> Application.put_env(:audit, Retention, original_config) end)
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
