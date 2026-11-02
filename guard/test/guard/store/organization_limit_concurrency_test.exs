defmodule Guard.Store.OrganizationLimitConcurrencyTest do
  # Runs against real, separately checked out connections (no sandbox
  # transaction), so concurrent creates are not serialized by a shared
  # connection. Rows are committed and removed in on_exit.
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Guard.FrontRepo

  @lock_namespace 1_330_464_355

  setup do
    previous = Application.get_env(:guard, :organization_limit_per_creator)
    Application.put_env(:guard, :organization_limit_per_creator, 3)

    creator_id = Ecto.UUID.generate()

    on_exit(fn ->
      if previous == nil,
        do: Application.delete_env(:guard, :organization_limit_per_creator),
        else: Application.put_env(:guard, :organization_limit_per_creator, previous)

      :ok = Sandbox.checkout(FrontRepo, sandbox: false)

      FrontRepo.query!("DELETE FROM organizations WHERE creator_id = $1", [
        Ecto.UUID.dump!(creator_id)
      ])

      Sandbox.checkin(FrontRepo)
    end)

    %{creator_id: creator_id}
  end

  test "parallel creates for one creator never exceed the limit", %{creator_id: creator_id} do
    parallel = 4
    parent = self()
    suffix = System.unique_integer([:positive])

    tasks =
      Enum.map(1..parallel, fn i ->
        Task.async(fn ->
          :ok = Sandbox.checkout(FrontRepo, sandbox: false)
          send(parent, {:ready, self()})

          receive do
            :go -> :ok
          end

          result =
            Guard.Store.Organization.create(%{
              name: "Parallel #{i}",
              username: "parallel-#{suffix}-#{i}",
              creator_id: creator_id
            })

          Sandbox.checkin(FrontRepo)
          result
        end)
      end)

    pids =
      Enum.map(1..parallel, fn _ ->
        receive do
          {:ready, pid} -> pid
        after
          5_000 -> flunk("task did not check out a connection")
        end
      end)

    Enum.each(pids, &send(&1, :go))

    results = Enum.map(tasks, &Task.await(&1, 15_000))

    assert Enum.count(results, &match?({:ok, _}, &1)) == 3
    assert Enum.count(results, &(&1 == {:error, :organization_limit_reached})) == parallel - 3
    assert live_count(creator_id) == 3
  end

  test "create waits for a concurrent holder of the creator lock", %{creator_id: creator_id} do
    parent = self()

    holder =
      Task.async(fn ->
        :ok = Sandbox.checkout(FrontRepo, sandbox: false)

        FrontRepo.transaction(fn ->
          FrontRepo.query!("SELECT pg_advisory_xact_lock($1, hashtext($2))", [
            @lock_namespace,
            creator_id
          ])

          send(parent, :locked)

          receive do
            :release -> :ok
          end
        end)

        Sandbox.checkin(FrontRepo)
      end)

    assert_receive :locked, 5_000

    creator =
      Task.async(fn ->
        :ok = Sandbox.checkout(FrontRepo, sandbox: false)

        result =
          Guard.Store.Organization.create(%{
            name: "Waiting",
            username: "waiting-#{System.unique_integer([:positive])}",
            creator_id: creator_id
          })

        Sandbox.checkin(FrontRepo)
        result
      end)

    assert Task.yield(creator, 300) == nil
    assert live_count(creator_id) == 0

    send(holder.pid, :release)
    Task.await(holder, 5_000)

    assert {:ok, organization} = Task.await(creator, 5_000)
    assert organization.creator_id == creator_id
  end

  defp live_count(creator_id) do
    task =
      Task.async(fn ->
        :ok = Sandbox.checkout(FrontRepo, sandbox: false)

        count =
          FrontRepo.query!(
            "SELECT count(*) FROM organizations WHERE creator_id = $1 AND deleted_at IS NULL",
            [Ecto.UUID.dump!(creator_id)]
          ).rows
          |> hd()
          |> hd()

        Sandbox.checkin(FrontRepo)
        count
      end)

    Task.await(task, 5_000)
  end
end
