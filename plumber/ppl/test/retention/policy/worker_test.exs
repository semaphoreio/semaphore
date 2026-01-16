defmodule Ppl.Retention.Policy.WorkerTest do
  use ExUnit.Case

  import Ecto.Query

  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.Retention.Policy.Worker
  alias Ppl.Retention.StateAgent

  setup do
    Test.Helpers.truncate_db()
    start_state_agent_if_needed()
    Worker.resume()
    :ok
  end

  defp start_state_agent_if_needed do
    case Process.whereis(StateAgent) do
      nil -> start_supervised!(StateAgent)
      _pid -> :ok
    end
  end

  describe "handle_message/1" do
    test "marks pipelines with expires_at ~15 days from now" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      Worker.handle_message(encode_event(org_id, cutoff))

      assert_expires_in_about_15_days(get_expires_at(pipeline.id))
    end

    test "handles multiple pipelines" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      old_pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])
      new_pipeline = insert_pipeline(org_id, ~N[2025-06-02 10:00:00.000000])

      Worker.handle_message(encode_event(org_id, cutoff))

      assert_expires_in_about_15_days(get_expires_at(old_pipeline.id))
      assert get_expires_at(new_pipeline.id) == nil
    end

    test "unmarks pipelines when cutoff moves backward" do
      org_id = UUID.uuid4()
      old_expires = ~N[2025-07-01 12:00:00.000000]

      pipeline_old = insert_pipeline(org_id, ~N[2025-04-01 10:00:00.000000])
      pipeline_between = insert_pipeline(org_id, ~N[2025-05-15 10:00:00.000000])

      set_expires_at(pipeline_old.id, old_expires)
      set_expires_at(pipeline_between.id, old_expires)

      Worker.handle_message(encode_event(org_id, ~N[2025-05-01 12:00:00.000000]))

      assert get_expires_at(pipeline_old.id) == old_expires
      assert get_expires_at(pipeline_between.id) == nil
    end

    test "ignores event with zero timestamp" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      message = OrganizationPolicyApply.encode(%OrganizationPolicyApply{
        org_id: org_id,
        cutoff_date: %Timestamp{seconds: 0, nanos: 0}
      })

      Worker.handle_message(message)

      assert get_expires_at(pipeline.id) == nil
    end

    test "ignores event with nil cutoff_date" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      message = OrganizationPolicyApply.encode(%OrganizationPolicyApply{
        org_id: org_id,
        cutoff_date: nil
      })

      Worker.handle_message(message)

      assert get_expires_at(pipeline.id) == nil
    end

    test "ignores event with empty org_id" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      message = OrganizationPolicyApply.encode(%OrganizationPolicyApply{
        org_id: "",
        cutoff_date: naive_to_timestamp(~N[2025-06-01 12:00:00.000000])
      })

      Worker.handle_message(message)

      assert get_expires_at(pipeline.id) == nil
    end

    test "handles invalid protobuf gracefully" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])

      Worker.handle_message(<<1, 2, 3, 4, 5>>)

      assert get_expires_at(pipeline.id) == nil
    end
  end

  describe "pause/resume" do
    test "starts in running state" do
      assert Worker.status() == :running
      assert Worker.paused?() == false
    end

    test "pause sets status to paused" do
      :ok = Worker.pause()
      assert Worker.status() == :paused
      assert Worker.paused?() == true
    end

    test "resume sets status to running" do
      :ok = Worker.pause()
      :ok = Worker.resume()
      assert Worker.status() == :running
    end

    test "pause_for expires after duration" do
      :ok = Worker.pause_for(10)
      assert Worker.paused?() == true
      :timer.sleep(20)
      assert Worker.paused?() == false
    end
  end

  describe "config" do
    test "returns current configuration" do
      config = Worker.config()
      assert is_integer(config.sleep_ms)
    end

    test "update_config changes sleep_ms" do
      :ok = Worker.update_config(sleep_ms: 5_000)
      assert Worker.config().sleep_ms == 5_000
    end
  end

  # Helpers

  defp insert_pipeline(org_id, inserted_at) do
    %PplRequests{
      id: UUID.uuid4(),
      ppl_artefact_id: UUID.uuid4(),
      wf_id: UUID.uuid4(),
      request_args: %{"organization_id" => org_id, "project_id" => UUID.uuid4(), "service" => "local"},
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
    OrganizationPolicyApply.encode(%OrganizationPolicyApply{
      org_id: org_id,
      cutoff_date: naive_to_timestamp(cutoff)
    })
  end

  defp naive_to_timestamp(naive) do
    datetime = DateTime.from_naive!(naive, "Etc/UTC")
    %Timestamp{
      seconds: DateTime.to_unix(datetime, :second),
      nanos: elem(naive.microsecond, 0) * 1_000
    }
  end

  defp get_expires_at(id) do
    from(pr in PplRequests, where: pr.id == ^id, select: pr.expires_at) |> EctoRepo.one()
  end

  defp set_expires_at(id, expires_at) do
    from(pr in PplRequests, where: pr.id == ^id) |> EctoRepo.update_all(set: [expires_at: expires_at])
  end

  defp assert_expires_in_about_15_days(expires_at) do
    expected = NaiveDateTime.add(NaiveDateTime.utc_now(), 15 * 24 * 60 * 60, :second)
    diff = abs(NaiveDateTime.diff(expires_at, expected, :second))
    assert diff < 60, "Expected expires_at ~15 days from now, got #{expires_at}"
  end
end
