defmodule Ppl.Retention.Policy.QueriesTest do
  use ExUnit.Case

  import Ecto.Query
  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.Retention.Policy.Queries

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  describe "mark_expiring/2" do
    test "marks pipelines inserted before cutoff with expires_at ~15 days from now" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      old_pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])
      recent_pipeline = insert_pipeline(org_id, ~N[2025-06-02 10:00:00.000000])

      {marked, unmarked} = Queries.mark_expiring(org_id, cutoff)

      assert marked == 1
      assert unmarked == 0

      expires_at = get_expires_at(old_pipeline.id)
      assert_expires_at_approximately_15_days_from_now(expires_at)
      assert get_expires_at(recent_pipeline.id) == nil
    end

    test "only marks pipelines for specified organization" do
      org_1 = UUID.uuid4()
      org_2 = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      pipeline_1 = insert_pipeline(org_1, ~N[2025-05-01 10:00:00.000000])
      pipeline_2 = insert_pipeline(org_2, ~N[2025-05-01 10:00:00.000000])

      {marked, unmarked} = Queries.mark_expiring(org_1, cutoff)

      assert marked == 1
      assert unmarked == 0
      assert_expires_at_approximately_15_days_from_now(get_expires_at(pipeline_1.id))
      assert get_expires_at(pipeline_2.id) == nil
    end

    test "does not re-mark already marked pipelines" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]
      existing_expires = ~N[2025-07-01 12:00:00.000000]

      pipeline = insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])
      set_expires_at(pipeline.id, existing_expires)

      {marked, unmarked} = Queries.mark_expiring(org_id, cutoff)

      assert marked == 0
      assert unmarked == 0
      assert get_expires_at(pipeline.id) == existing_expires
    end

    test "unmarks pipelines when cutoff moves backward" do
      org_id = UUID.uuid4()
      old_expires = ~N[2025-07-01 12:00:00.000000]

      pipeline_old = insert_pipeline(org_id, ~N[2025-04-01 10:00:00.000000])
      pipeline_between = insert_pipeline(org_id, ~N[2025-05-15 10:00:00.000000])
      pipeline_recent = insert_pipeline(org_id, ~N[2025-06-02 10:00:00.000000])

      set_expires_at(pipeline_old.id, old_expires)
      set_expires_at(pipeline_between.id, old_expires)

      new_cutoff = ~N[2025-05-01 12:00:00.000000]
      {marked, unmarked} = Queries.mark_expiring(org_id, new_cutoff)

      assert marked == 0
      assert unmarked == 1

      assert get_expires_at(pipeline_old.id) == old_expires
      assert get_expires_at(pipeline_between.id) == nil
      assert get_expires_at(pipeline_recent.id) == nil
    end

    test "handles multiple pipelines in batch" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      Enum.each(1..10, fn _ ->
        insert_pipeline(org_id, ~N[2025-05-01 10:00:00.000000])
      end)

      Enum.each(1..5, fn _ ->
        insert_pipeline(org_id, ~N[2025-06-02 10:00:00.000000])
      end)

      {marked, unmarked} = Queries.mark_expiring(org_id, cutoff)

      assert marked == 10
      assert unmarked == 0
    end

    test "returns {0, 0} when no pipelines match criteria" do
      org_id = UUID.uuid4()
      cutoff = ~N[2025-06-01 12:00:00.000000]

      insert_pipeline(org_id, ~N[2025-06-02 10:00:00.000000])

      {marked, unmarked} = Queries.mark_expiring(org_id, cutoff)

      assert marked == 0
      assert unmarked == 0
    end

    test "does not unmark pipelines from other organizations" do
      org_1 = UUID.uuid4()
      org_2 = UUID.uuid4()
      cutoff = ~N[2025-05-01 12:00:00.000000]
      old_expires = ~N[2025-07-01 12:00:00.000000]

      pipeline_org1 = insert_pipeline(org_1, ~N[2025-05-15 10:00:00.000000])
      pipeline_org2 = insert_pipeline(org_2, ~N[2025-05-15 10:00:00.000000])

      set_expires_at(pipeline_org1.id, old_expires)
      set_expires_at(pipeline_org2.id, old_expires)

      {marked, unmarked} = Queries.mark_expiring(org_1, cutoff)

      assert marked == 0
      assert unmarked == 1
      assert get_expires_at(pipeline_org1.id) == nil
      assert get_expires_at(pipeline_org2.id) == old_expires
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
