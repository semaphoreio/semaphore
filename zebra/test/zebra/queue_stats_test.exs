defmodule Zebra.QueueStatsTest do
  use Zebra.DataCase

  alias Support.Factories
  alias Zebra.QueueStats

  @now ~U[2026-01-01 12:00:00Z]

  describe ".compute" do
    test "counts only scheduled jobs as waiting" do
      {:ok, _} = Factories.Job.create(:pending, %{machine_type: "f1-standard-2"})
      {:ok, _} = Factories.Job.create(:enqueued, %{machine_type: "f1-standard-2"})
      {:ok, _} = Factories.Job.create(:scheduled, %{machine_type: "f1-standard-2"})
      {:ok, _} = Factories.Job.create(:scheduled, %{machine_type: "f1-standard-2"})
      {:ok, _} = Factories.Job.create(:started, %{machine_type: "f1-standard-2"})
      {:ok, _} = Factories.Job.create(:finished, %{machine_type: "f1-standard-2"})

      assert {:ok, [queue]} = QueueStats.compute()
      assert queue.machine_type == "f1-standard-2"
      assert queue.os_image == "ubuntu1804"
      assert queue.waiting == 2
      assert queue.waiting_orgs == 1
      refute queue.self_hosted
    end

    test "returns no queues when nothing waits" do
      {:ok, _} = Factories.Job.create(:enqueued, %{machine_type: "f1-standard-2"})
      {:ok, _} = Factories.Job.create(:started, %{machine_type: "f1-standard-2"})

      assert {:ok, []} = QueueStats.compute()
    end

    test "groups by machine type and image, and counts distinct orgs" do
      other_org = Ecto.UUID.generate()

      {:ok, _} = Factories.Job.create(:scheduled, %{machine_type: "f1-standard-2"})

      {:ok, _} =
        Factories.Job.create(:scheduled, %{
          machine_type: "f1-standard-2",
          organization_id: other_org
        })

      {:ok, _} =
        Factories.Job.create(:scheduled, %{
          machine_type: "f1-standard-2",
          machine_os_image: "ubuntu2404"
        })

      {:ok, _} = Factories.Job.create(:scheduled, %{machine_type: "f1-standard-4"})

      assert {:ok, queues} = QueueStats.compute()

      assert Enum.map(queues, &{&1.machine_type, &1.os_image, &1.waiting, &1.waiting_orgs}) == [
               {"f1-standard-2", "ubuntu1804", 2, 2},
               {"f1-standard-2", "ubuntu2404", 1, 1},
               {"f1-standard-4", "ubuntu1804", 1, 1}
             ]
    end

    test "tracks the oldest scheduled job" do
      older = DateTime.add(@now, -120, :second)

      {:ok, _} =
        Factories.Job.create(:scheduled, %{machine_type: "f1-standard-2", scheduled_at: @now})

      {:ok, _} =
        Factories.Job.create(:scheduled, %{machine_type: "f1-standard-2", scheduled_at: older})

      assert {:ok, [queue]} = QueueStats.compute()
      assert queue.oldest_scheduled_at == older
      assert QueueStats.oldest_wait_seconds(queue, @now) == 120
    end

    test "marks self-hosted machine types" do
      {:ok, _} = Factories.Job.create(:scheduled, %{machine_type: "s1-my-agents"})
      {:ok, _} = Factories.Job.create(:scheduled, %{machine_type: "f1-standard-2"})

      assert {:ok, queues} = QueueStats.compute()
      assert [%{machine_type: "s1-my-agents"}] = QueueStats.filter(queues, :SELF_HOSTED)
      assert [%{machine_type: "f1-standard-2"}] = QueueStats.filter(queues, :CLOUD)
      assert length(QueueStats.filter(queues, :ALL)) == 2
    end

    test "keeps the type when the org has no migration flag" do
      {:ok, _} = Factories.Job.create(:scheduled, %{machine_type: "e1-standard-2"})

      assert {:ok, [queue]} = QueueStats.compute()
      assert queue.machine_type == "e1-standard-2"
    end
  end

  describe ".aggregate" do
    test "merges rows that translate to the same machine" do
      e1_org = Support.StubbedProvider.e1_to_f1_org_id()
      e2_org = Support.StubbedProvider.e2_to_f1_org_id()
      plain_org = "org-without-flags"
      older = DateTime.add(@now, -60, :second)

      rows = [
        {"e1-standard-2", "ubuntu2004", e1_org, 3, @now},
        {"e2-standard-2", "ubuntu2004", e2_org, 2, older},
        {"f1-standard-2", "ubuntu2004", plain_org, 1, @now},
        {"e1-standard-2", "ubuntu2004", plain_org, 4, @now}
      ]

      assert QueueStats.aggregate(rows) == [
               %QueueStats.Queue{
                 machine_type: "e1-standard-2",
                 os_image: "ubuntu2004",
                 waiting: 4,
                 oldest_scheduled_at: @now,
                 waiting_orgs: 1,
                 self_hosted: false
               },
               %QueueStats.Queue{
                 machine_type: "f1-standard-2",
                 os_image: "ubuntu2004",
                 waiting: 6,
                 oldest_scheduled_at: older,
                 waiting_orgs: 3,
                 self_hosted: false
               }
             ]
    end

    test "maps larger e1 and e2 types to the larger target type" do
      e1_org = Support.StubbedProvider.e1_to_f1_org_id()
      e2_org = Support.StubbedProvider.e2_to_f1_org_id()

      rows = [
        {"e1-standard-8", "img", e1_org, 1, @now},
        {"e2-standard-4", "img", e2_org, 1, @now}
      ]

      assert [%{machine_type: "f1-standard-4", waiting: 2, waiting_orgs: 2}] =
               QueueStats.aggregate(rows)
    end

    test "merges nil and empty images" do
      rows = [
        {"f1-standard-2", nil, "org-a", 1, @now},
        {"f1-standard-2", "", "org-b", 1, @now}
      ]

      assert [%{os_image: "", waiting: 2, waiting_orgs: 2}] = QueueStats.aggregate(rows)
    end

    test "keeps the machine when the flag lookup fails" do
      Mox.stub(Support.MockedProvider, :provide_features, fn _, _ -> raise "lookup failed" end)

      rows = [{"e1-standard-2", "img", "org-a", 1, @now}]

      assert [%{machine_type: "e1-standard-2", waiting: 1}] = QueueStats.aggregate(rows)
    end
  end

  describe "server" do
    test "is not ready before the first refresh, then serves the snapshot" do
      parent = self()

      compute = fn ->
        send(parent, :computed)
        {:ok, [%QueueStats.Queue{machine_type: "f1-standard-2", waiting: 1}]}
      end

      {:ok, pid} = QueueStats.start_link(name: nil, compute: compute)

      assert QueueStats.get(pid) == {:error, :not_ready}
      assert_receive :computed

      assert {:ok, snapshot, age_ms} = wait_for_snapshot(pid)
      assert [%{waiting: 1}] = snapshot.queues
      assert age_ms >= 0
    end

    test "runs at most one refresh at a time" do
      parent = self()

      compute = fn ->
        send(parent, :started)

        receive do
          :finish -> {:ok, []}
        end
      end

      {:ok, pid} = QueueStats.start_link(name: nil, compute: compute, refresh_after_ms: 0)

      for _ <- 1..5, do: QueueStats.get(pid)

      assert_receive :started
      refute_receive :started, 100
    end

    test "keeps the previous snapshot when a refresh fails" do
      {:ok, agent} = Agent.start_link(fn -> {:ok, [%QueueStats.Queue{waiting: 7}]} end)
      compute = fn -> Agent.get(agent, & &1) end

      {:ok, pid} = QueueStats.start_link(name: nil, compute: compute, refresh_after_ms: 0)
      assert {:ok, %{queues: [%{waiting: 7}]}, _} = QueueStats.refresh_sync(pid)

      Agent.update(agent, fn _ -> {:error, :db_down} end)
      assert {:ok, %{queues: [%{waiting: 7}]}, _} = QueueStats.refresh_sync(pid)
    end

    test "kills a refresh that runs past the timeout" do
      parent = self()

      compute = fn ->
        send(parent, {:started, self()})
        Process.sleep(:infinity)
      end

      {:ok, pid} =
        QueueStats.start_link(
          name: nil,
          compute: compute,
          refresh_after_ms: 0,
          refresh_timeout_ms: 50,
          backoff_base_ms: 10
        )

      QueueStats.get(pid)
      assert_receive {:started, task_pid}
      ref = Process.monitor(task_pid)
      assert_receive {:DOWN, ^ref, :process, _, _}, 500

      # A new refresh can start once the stuck one is gone and the backoff passed.
      Process.sleep(30)
      QueueStats.get(pid)
      assert_receive {:started, _}, 500
    end

    test "backs off after a failed refresh, then retries" do
      parent = self()

      compute = fn ->
        send(parent, :computed)
        {:error, :db_down}
      end

      {:ok, pid} =
        QueueStats.start_link(
          name: nil,
          compute: compute,
          refresh_after_ms: 0,
          backoff_base_ms: 200,
          backoff_max_ms: 1_000
        )

      assert QueueStats.get(pid) == {:error, :not_ready}
      assert_receive :computed

      # Requests inside the backoff window start no new refresh.
      Process.sleep(20)
      for _ <- 1..5, do: QueueStats.get(pid)
      refute_receive :computed, 100

      # After the backoff, the next request retries.
      Process.sleep(150)
      QueueStats.get(pid)
      assert_receive :computed, 500
    end

    test "the backoff grows and is capped" do
      {:ok, agent} = Agent.start_link(fn -> [] end)
      parent = self()

      compute = fn ->
        Agent.update(agent, &[System.monotonic_time(:millisecond) | &1])
        send(parent, :computed)
        {:error, :db_down}
      end

      {:ok, pid} =
        QueueStats.start_link(
          name: nil,
          compute: compute,
          refresh_after_ms: 0,
          backoff_base_ms: 40,
          backoff_max_ms: 100
        )

      # Poll steadily; refreshes happen only when the backoff allows.
      for _ <- 1..60 do
        QueueStats.get(pid)
        Process.sleep(10)
      end

      times = agent |> Agent.get(& &1) |> Enum.reverse()
      gaps = times |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)

      assert length(times) >= 4
      # 40, 80, then capped at 100 (allow scheduling slack).
      assert Enum.at(gaps, 0) >= 40
      assert Enum.at(gaps, 1) >= 80
      assert Enum.all?(gaps, &(&1 < 160))
    end

    test "a successful refresh resets the backoff" do
      {:ok, agent} = Agent.start_link(fn -> {:error, :db_down} end)
      compute = fn -> Agent.get(agent, & &1) end

      {:ok, pid} =
        QueueStats.start_link(
          name: nil,
          compute: compute,
          refresh_after_ms: 0,
          backoff_base_ms: 5_000
        )

      assert {:error, :not_ready} = QueueStats.refresh_sync(pid)
      Agent.update(agent, fn _ -> {:ok, [%QueueStats.Queue{waiting: 1}]} end)
      assert {:ok, %{queues: [%{waiting: 1}]}, _} = QueueStats.refresh_sync(pid)
      assert :sys.get_state(pid).failures == 0
      assert :sys.get_state(pid).retry_at_ms == nil
    end

    test "answers not ready when the server is not running" do
      assert QueueStats.get(:queue_stats_not_running) == {:error, :not_ready}
    end
  end

  defp wait_for_snapshot(pid, attempts \\ 50) do
    case QueueStats.get(pid) do
      {:ok, _, _} = ok ->
        ok

      {:error, :not_ready} when attempts > 0 ->
        Process.sleep(10)
        wait_for_snapshot(pid, attempts - 1)

      other ->
        other
    end
  end
end
