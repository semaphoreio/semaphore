defmodule Test.Actions.BulkUpsertAndPruneImpl.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Scheduler.Actions.BulkUpsertAndPruneImpl
  alias Scheduler.DeleteRequests.Model.DeleteRequests
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.PeriodicsRepo
  alias Scheduler.Workers.QuantumScheduler
  alias Test.Support.Factory

  setup do
    Test.Helpers.truncate_db()
    params = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    {:ok, params}
  end

  describe "happy path" do
    test "creates all periodics on an empty project", ctx do
      params =
        base_params(ctx, [definition("alpha", "0 0 * * *"), definition("beta", "5 0 * * *")])

      assert {:ok, %{upserted: upserted, deleted_ids: []}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)

      assert length(upserted) == 2
      names = Enum.map(upserted, & &1.name)
      assert "alpha" in names
      assert "beta" in names

      persisted = list_periodics_for(ctx.pr_id)
      assert length(persisted) == 2

      for periodic <- upserted do
        assert periodic.id |> String.to_atom() |> QuantumScheduler.find_job()
      end
    end

    test "updates an existing periodic and inserts a new one in one call", ctx do
      {:ok, periodic: existing} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "alpha",
          at: "0 0 * * *"
        )

      params =
        base_params(ctx, [
          definition("alpha", "30 0 * * *", id: existing.id),
          definition("delta", "0 1 * * *")
        ])

      assert {:ok, %{upserted: upserted, deleted_ids: []}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)

      assert length(upserted) == 2
      [alpha] = Enum.filter(upserted, &(&1.name == "alpha"))
      assert alpha.id == existing.id
      assert alpha.at == "30 0 * * *"
    end

    test "prunes existing periodics that are not in the desired set", ctx do
      {:ok, periodic: keep} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "keep"
        )

      {:ok, periodic: gone1} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "gone-1"
        )

      {:ok, periodic: gone2} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "gone-2"
        )

      QuantumScheduler.start_periodic_job(gone1)

      params = base_params(ctx, [definition("keep", "0 0 * * *", id: keep.id)])

      assert {:ok, %{upserted: [_], deleted_ids: deleted}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)

      assert MapSet.new(deleted) == MapSet.new([gone1.id, gone2.id])

      persisted = list_periodics_for(ctx.pr_id)
      assert length(persisted) == 1
      assert hd(persisted).id == keep.id

      audit_count = audit_count_for(ctx.pr_id)
      assert audit_count >= 2

      refute gone1.id |> String.to_atom() |> QuantumScheduler.find_job()
    end

    test "an empty batch deletes every periodic on the project", ctx do
      {:ok, periodic: _} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "a"
        )

      {:ok, periodic: _} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "b"
        )

      params = base_params(ctx, [])

      assert {:ok, %{upserted: [], deleted_ids: deleted}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)

      assert length(deleted) == 2
      assert list_periodics_for(ctx.pr_id) == []
    end
  end

  describe "validation rollback" do
    test "invalid cron in any task rejects entire batch and leaves DB unchanged", ctx do
      {:ok, periodic: existing} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "keep-me"
        )

      params =
        base_params(ctx, [
          definition("valid-new", "0 0 * * *"),
          definition("bad-cron", "this is not a cron")
        ])

      assert {:error, {:INVALID_ARGUMENT, message}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)

      assert message =~ "bad-cron"

      persisted = list_periodics_for(ctx.pr_id)
      assert length(persisted) == 1
      assert hd(persisted).id == existing.id
    end

    test "duplicate names within the batch roll back all inserts", ctx do
      {:ok, periodic: existing} =
        Factory.setup_periodic(ctx,
          organization_id: ctx.org_id,
          project_id: ctx.pr_id,
          requester_id: ctx.usr_id,
          name: "untouched"
        )

      params =
        base_params(ctx, [
          definition("clash", "0 0 * * *"),
          definition("clash", "0 1 * * *")
        ])

      assert {:error, {:INVALID_ARGUMENT, _message}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)

      persisted = list_periodics_for(ctx.pr_id)
      assert length(persisted) == 1
      assert hd(persisted).id == existing.id
    end

    test "unknown project_id returns FAILED_PRECONDITION", ctx do
      params = base_params(%{ctx | pr_id: UUID.uuid4()}, [definition("alpha", "0 0 * * *")])

      assert {:error, {:FAILED_PRECONDITION, _message}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)
    end

    test "empty organization_id returns INVALID_ARGUMENT", ctx do
      params = %{base_params(ctx, []) | organization_id: ""}

      assert {:error, {:INVALID_ARGUMENT, _}} =
               BulkUpsertAndPruneImpl.bulk_upsert_and_prune(params)
    end
  end

  defp base_params(ctx, periodics) do
    %{
      organization_id: ctx.org_id,
      project_id: ctx.pr_id,
      requester_id: ctx.usr_id,
      periodics: periodics
    }
  end

  defp definition(name, at, opts \\ []) do
    %{
      id: Keyword.get(opts, :id, ""),
      name: name,
      description: Keyword.get(opts, :description, ""),
      recurring: Keyword.get(opts, :recurring, true),
      reference: Keyword.get(opts, :reference, "refs/heads/master"),
      at: at,
      pipeline_file: Keyword.get(opts, :pipeline_file, ".semaphore/cron.yml"),
      parameters: Keyword.get(opts, :parameters, [])
    }
  end

  defp list_periodics_for(project_id) do
    Periodics
    |> where([p], p.project_id == ^project_id)
    |> PeriodicsRepo.all()
  end

  defp audit_count_for(project_id) do
    periodic_ids =
      Periodics
      |> where([p], p.project_id == ^project_id)
      |> select([p], p.id)
      |> PeriodicsRepo.all()

    DeleteRequests
    |> select([d], count(d.id))
    |> where([d], d.periodic_id not in ^periodic_ids)
    |> PeriodicsRepo.one()
  end
end
