defmodule Zebra.Workers.DbWorkerTest do
  use Zebra.DataCase

  import ExUnit.CaptureLog

  alias Zebra.Models.Job
  alias Zebra.Workers.DbWorker

  defp worker(processor, opts) do
    struct(
      %DbWorker{
        schema: Job,
        state_field: :aasm_state,
        state_value: Job.state_pending(),
        metric_name: "db_worker_test",
        order_by: :created_at,
        order_direction: :asc,
        naptime: 1000,
        processor: processor
      },
      opts
    )
  end

  # Distinct created_at values, oldest first, so the tick reads the rows in
  # the order they are returned here. A fresh organization keeps the rows
  # away from scheduler runs that other tests start with Job.enqueue/3.
  defp create_pending_jobs(n) do
    org_id = Ecto.UUID.generate()
    base = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-n, :second)

    Enum.map(1..n, fn i ->
      created_at = DateTime.add(base, i, :second)

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          organization_id: org_id,
          created_at: created_at,
          updated_at: created_at
        })

      job
    end)
  end

  # A plain update: Job.enqueue/3 would also kick off the scheduler.
  defp mark_enqueued(job) do
    job |> Ecto.Changeset.change(aasm_state: Job.state_enqueued()) |> Zebra.LegacyRepo.update()
  end

  defp eventually(fun, attempts \\ 20) do
    cond do
      fun.() ->
        true

      attempts == 1 ->
        false

      true ->
        :timer.sleep(100)
        eventually(fun, attempts - 1)
    end
  end

  describe "continuous mode" do
    test "processes every row" do
      jobs = create_pending_jobs(5)
      test_pid = self()

      processor = fn job ->
        send(test_pid, {:processed, job.id})
        {:ok, job}
      end

      DbWorker.tick(worker(processor, concurrency_mode: :continuous, parallelism: 2))

      Enum.each(jobs, fn job -> assert_received {:processed, id} when id == job.id end)
    end

    test "a slow row does not hold back the rows after it" do
      [slow | fast] = create_pending_jobs(4)
      test_pid = self()

      processor = fn job ->
        if job.id == slow.id, do: :timer.sleep(500)
        send(test_pid, {:processed, job.id})
        {:ok, job}
      end

      DbWorker.tick(worker(processor, concurrency_mode: :continuous, parallelism: 2))

      # The slow row is read first. With batches of 2, the third and fourth
      # rows would only start after it finished. In continuous mode, every
      # fast row finishes while the slow one is still sleeping.
      processed =
        Enum.map(1..4, fn _ ->
          assert_received {:processed, id}
          id
        end)

      assert List.last(processed) == slow.id
      assert Enum.sort(Enum.take(processed, 3)) == Enum.sort(Enum.map(fast, & &1.id))
    end

    test "rolls back a row that runs past the timeout, processes the rest, and retries it later" do
      [stuck | rest] = create_pending_jobs(3)

      # The stuck row updates its state and then hangs inside the transaction,
      # so it stays pending only if the transaction is rolled back.
      processor = fn job ->
        result = mark_enqueued(job)
        if job.id == stuck.id, do: Process.sleep(:infinity)
        result
      end

      log =
        capture_log(fn ->
          results =
            DbWorker.tick(
              worker(processor,
                concurrency_mode: :continuous,
                parallelism: 3,
                process_timeout: 1_000
              )
            )

          assert {:error, :timeout} in results
        end)

      assert log =~ stuck.id

      assert Job.reload(stuck).aasm_state == Job.state_pending()
      Enum.each(rest, fn job -> assert Job.reload(job).aasm_state == Job.state_enqueued() end)

      # Postgres releases the row lock once it notices the killed connection
      # is gone, so a later tick picks the row up again.
      retry = worker(&mark_enqueued/1, concurrency_mode: :continuous, process_timeout: 1_000)

      assert eventually(fn ->
               DbWorker.tick(retry)
               Job.reload(stuck).aasm_state == Job.state_enqueued()
             end)
    end

    test "skips a row that hits a DB connection error and processes the rest" do
      [broken | rest] = create_pending_jobs(3)

      processor = fn job ->
        if job.id == broken.id, do: raise(DBConnection.ConnectionError, "connection lost")
        mark_enqueued(job)
      end

      log =
        capture_log(fn ->
          results = DbWorker.tick(worker(processor, concurrency_mode: :continuous))

          assert {:error, :db_connection} in results
        end)

      assert log =~ "DB connection error for #{broken.id}"

      assert Job.reload(broken).aasm_state == Job.state_pending()
      Enum.each(rest, fn job -> assert Job.reload(job).aasm_state == Job.state_enqueued() end)
    end

    test "raises on an unknown concurrency mode" do
      create_pending_jobs(1)

      assert_raise ArgumentError, ~r/unknown concurrency_mode :parallel/, fn ->
        DbWorker.tick(worker(fn job -> {:ok, job} end, concurrency_mode: :parallel))
      end
    end
  end

  describe "process/2 in continuous mode" do
    test "uses process_timeout as the transaction timeout" do
      [job] = create_pending_jobs(1)

      # Sleeps past the 200ms budget while holding the connection, then writes.
      # With the repo's default 15s timeout the write would succeed.
      processor = fn job ->
        :timer.sleep(600)
        mark_enqueued(job)
      end

      worker = worker(processor, concurrency_mode: :continuous, process_timeout: 200)

      capture_log(fn ->
        assert_raise DBConnection.ConnectionError, fn -> DbWorker.process(worker, job.id) end
      end)

      assert Job.reload(job).aasm_state == Job.state_pending()
    end
  end

  describe "batches mode" do
    test "stays the default and still halts the tick" do
      create_pending_jobs(4)
      test_pid = self()

      processor = fn job ->
        send(test_pid, {:processed, job.id})
        {:halt, job}
      end

      DbWorker.tick(worker(processor, parallelism: 2))

      assert_received {:processed, _}
      assert_received {:processed, _}
      refute_received {:processed, _}
    end
  end
end
