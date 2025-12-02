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
    test "decodes valid event and marks pipelines" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      message = encode_event(org_id, cutoff)
      PolicyConsumer.handle_message(message)

      assert get_expires_at(pipeline.id) == cutoff
    end

    test "handles multiple pipelines for organization" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      pipeline_1 = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])
      pipeline_2 = insert_pipeline(org_id, ~N[2025-05-15 10:00:00.000000])
      pipeline_3 = insert_pipeline(org_id, ~N[2025-06-02 10:00:00.000000])

      message = encode_event(org_id, cutoff)
      PolicyConsumer.handle_message(message)

      assert get_expires_at(pipeline_1.id) == cutoff
      assert get_expires_at(pipeline_2.id) == cutoff
      assert get_expires_at(pipeline_3.id) == nil
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

      expected = ~N[2025-06-01 12:30:45.123456]
      assert get_expires_at(pipeline.id) == expected
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
end
