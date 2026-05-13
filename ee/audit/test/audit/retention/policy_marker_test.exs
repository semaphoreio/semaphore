defmodule Audit.Retention.PolicyMarkerTest do
  use Support.DataCase

  alias Audit.Event
  alias Audit.Retention.PolicyMarker
  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Support.RetentionFixtures

  test "marks old events and keeps recent events" do
    org_id = Ecto.UUID.generate()
    cutoff = DateTime.from_unix!(1_735_603_200)

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

  test "accepts policy event cutoff slightly in the future (clock skew tolerance)" do
    org_id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    old_event =
      RetentionFixtures.insert_event(%{
        org_id: org_id,
        timestamp: DateTime.add(now, -120, :second)
      })

    near_future_cutoff = DateTime.add(now, 30, :second)

    assert :ok = PolicyMarker.handle_message(encode_policy_event(org_id, near_future_cutoff))
    refute is_nil(get_event(old_event.id).expires_at)
  end

  defp encode_policy_event(org_id, cutoff) do
    RetentionFixtures.encode_policy_event(org_id, cutoff)
  end

  defp get_event(event_id), do: Repo.get!(Event, event_id)
end
