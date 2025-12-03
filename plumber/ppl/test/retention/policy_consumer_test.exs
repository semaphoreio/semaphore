defmodule Ppl.Retention.PolicyConsumerTest do
  use ExUnit.Case

  import Ecto.Query
  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.Retention.PolicyConsumer

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  describe "handle_message/1" do
    test "decodes valid event and marks pipelines with expires_at ~15 days from now" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      message = encode_event(org_id, cutoff)
      PolicyConsumer.handle_message(message)

      expires_at = get_expires_at(pipeline.id)
      assert_expires_at_approximately_15_days_from_now(expires_at)
    end

    test "handles multiple pipelines for organization" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      pipeline_1 = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])
      pipeline_2 = insert_pipeline(org_id, ~N[2025-05-15 10:00:00.000000])
      pipeline_3 = insert_pipeline(org_id, ~N[2025-06-02 10:00:00.000000])

      message = encode_event(org_id, cutoff)
      PolicyConsumer.handle_message(message)

      assert_expires_at_approximately_15_days_from_now(get_expires_at(pipeline_1.id))
      assert_expires_at_approximately_15_days_from_now(get_expires_at(pipeline_2.id))
      assert get_expires_at(pipeline_3.id) == nil
    end

    test "unmarks pipelines when cutoff moves backward" do
      org_id = UUID.uuid4()
      old_expires = ~N[2025-07-01 12:00:00.000000]

      pipeline_old = insert_pipeline(org_id, ~N[2025-04-01 10:00:00.000000])
      pipeline_between = insert_pipeline(org_id, ~N[2025-05-15 10:00:00.000000])

      set_expires_at(pipeline_old.id, old_expires)
      set_expires_at(pipeline_between.id, old_expires)

      new_cutoff = ~N[2025-05-01 12:00:00.000000]
      message = encode_event(org_id, new_cutoff)
      PolicyConsumer.handle_message(message)

      assert_expires_at_approximately_15_days_from_now(get_expires_at(pipeline_old.id))
      assert get_expires_at(pipeline_between.id) == nil
    end

    test "handles event with zero timestamp" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      event = %OrganizationPolicyApply{
        org_id: org_id,
        cutoff_date: %Timestamp{seconds: 0, nanos: 0}
      }
      message = OrganizationPolicyApply.encode(event)

      PolicyConsumer.handle_message(message)

      assert get_expires_at(pipeline.id) == nil
    end

    test "handles event with nil cutoff_date" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      event = %OrganizationPolicyApply{
        org_id: org_id,
        cutoff_date: nil
      }
      message = OrganizationPolicyApply.encode(event)

      PolicyConsumer.handle_message(message)

      assert get_expires_at(pipeline.id) == nil
    end

    test "handles event with empty org_id" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      event = %OrganizationPolicyApply{
        org_id: "",
        cutoff_date: naive_to_timestamp(cutoff)
      }
      message = OrganizationPolicyApply.encode(event)

      PolicyConsumer.handle_message(message)

      assert get_expires_at(pipeline.id) == nil
    end

    test "handles invalid protobuf message" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      message = <<1, 2, 3, 4, 5>>

      PolicyConsumer.handle_message(message)

      assert get_expires_at(pipeline.id) == nil
    end

    test "converts timestamp with nanoseconds correctly" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      datetime = DateTime.from_naive!(~N[2025-06-01 12:30:45.123456], "Etc/UTC")
      event = %OrganizationPolicyApply{
        org_id: org_id,
        cutoff_date: %Timestamp{
          seconds: DateTime.to_unix(datetime, :second),
          nanos: 123_456_000
        }
      }
      message = OrganizationPolicyApply.encode(event)

      PolicyConsumer.handle_message(message)

      assert_expires_at_approximately_15_days_from_now(get_expires_at(pipeline.id))
    end
  end

  defp insert_pipeline(org_id, inserted_at) do
    id = UUID.uuid4()
    ppl_id = UUID.uuid4()
    wf_id = UUID.uuid4()

    request_args = %{
      "organization_id" => org_id,
      "project_id" => UUID.uuid4(),
      "service" => "local"
    }

    %PplRequests{
      id: id,
      ppl_artefact_id: ppl_id,
      wf_id: wf_id,
      request_args: request_args,
      request_token: UUID.uuid1(),
      definition: %{"version" => "v1.0", "blocks" => []},
      top_level: true,
      initial_request: true,
      prev_ppl_artefact_ids: [],
      inserted_at: inserted_at
    }
    |> EctoRepo.insert!()
  end

  defp encode_event(org_id, cutoff) do
    event = %OrganizationPolicyApply{
      org_id: org_id,
      cutoff_date: naive_to_timestamp(cutoff)
    }

    OrganizationPolicyApply.encode(event)
  end

  defp naive_to_timestamp(naive_datetime) do
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    seconds = DateTime.to_unix(datetime, :second)
    micros = naive_datetime.microsecond |> elem(0)
    nanos = micros * 1_000

    %Timestamp{seconds: seconds, nanos: nanos}
  end

  defp get_expires_at(pipeline_id) do
    from(pr in PplRequests, where: pr.id == ^pipeline_id, select: pr.expires_at)
    |> EctoRepo.one()
  end

  defp set_expires_at(pipeline_id, expires_at) do
    from(pr in PplRequests, where: pr.id == ^pipeline_id)
    |> EctoRepo.update_all(set: [expires_at: expires_at])
  end

  defp assert_expires_at_approximately_15_days_from_now(expires_at) do
    now = NaiveDateTime.utc_now()
    fifteen_days_in_seconds = 15 * 24 * 60 * 60
    expected = NaiveDateTime.add(now, fifteen_days_in_seconds, :second)
    diff_seconds = NaiveDateTime.diff(expires_at, expected, :second) |> abs()
    assert diff_seconds < 60, "Expected expires_at to be ~15 days from now, got #{expires_at}"
  end
end
