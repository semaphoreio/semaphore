defmodule Looper.STMTest do
  use ExUnit.Case

  import Ecto.Query

  alias Looper.STM.Test.Items
  alias Looper.Test.EctoRepo

  defmodule RunEpilogueAfterCommit do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 30,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}

    def epilogue_handler({:ok, %{:exit_transition => item}}) do
      from(p in Items, where: p.id == ^item.id)
      |> EctoRepo.update_all(set: [description: %{"epilogue" => "executed"}])
    end
  end

  test "STM runs epilogue - transaction commited" do
    EctoRepo.delete_all Items

    {:ok, %{:id => id, :description => description}} =
      %Items{state: "initializing"}
      |> EctoRepo.insert

    assert description == nil

    Looper.STMTest.RunEpilogueAfterCommit.start_link()
    :timer.sleep(50)
    Looper.STMTest.RunEpilogueAfterCommit.stop()

    %{:description => description} =
      from(p in Items, where: p.id == ^id)
      |> EctoRepo.one()

    assert description == %{"epilogue" => "executed"}
  end

  defmodule RunEpilogueAfterAbort do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 30,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:error, %{}} end}

    def epilogue_handler({:error, _, _,  %{item: item}}) do
      from(p in Items, where: p.id == ^item.id)
      |> EctoRepo.update_all(set: [description: %{"epilogue" => "executed"}])
    end
  end

  test "STM runs epilogue - transaction aborted" do
    EctoRepo.delete_all Items

    {:ok, %{:id => id, :description => description}} =
      %Items{state: "initializing"}
      |> EctoRepo.insert

    assert description == nil

    Looper.STMTest.RunEpilogueAfterAbort.start_link()
    :timer.sleep(50)
    Looper.STMTest.RunEpilogueAfterAbort.stop()

    %{:description => description} =
      from(p in Items, where: p.id == ^id)
      |> EctoRepo.one()

    assert description == %{"epilogue" => "executed"}
  end

  defmodule ExecuteNowWithPredicate do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 3_000,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}

  end

  test "execute_now_with_predicate execution" do
    EctoRepo.delete_all Items

    {:ok, %{:id => id, :state => state}} =
      %Items{state: "initializing"} |> EctoRepo.insert()

    assert state == "initializing"

    Looper.STMTest.ExecuteNowWithPredicate.start_link()
    call_execute_now_with_predicate(id)
    :timer.sleep(50)
    Looper.STMTest.ExecuteNowWithPredicate.stop()

    %{:state => state} = from(p in Items, where: p.id == ^id) |> EctoRepo.one()

    assert state == "running"
  end

  defp call_execute_now_with_predicate(id) do
    import Ecto.Query

    fn query -> query |> where(id: ^id) end
    |> Looper.STMTest.ExecuteNowWithPredicate.execute_now_with_predicate()
  end

  defmodule ExecuteNowTask do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 3_000,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count],
      task_supervisor: TestTaskSupervisor

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}

  end

  test "execute_now_in_task execution" do
    EctoRepo.delete_all Items

    {:ok, %{:id => id, :state => state}} =
      %Items{state: "initializing"} |> EctoRepo.insert()

    assert state == "initializing"

    Task.Supervisor.start_link(name: TestTaskSupervisor)

    call_execute_now_in_task(id)

    :timer.sleep(50)

    %{:state => state} = from(p in Items, where: p.id == ^id) |> EctoRepo.one()

    assert state == "running"
  end

  defp call_execute_now_in_task(id) do
    import Ecto.Query

    fn query -> query |> where(id: ^id) end
    |> Looper.STMTest.ExecuteNowTask.execute_now_in_task()
  end

  defmodule BatchOfThree do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 60_000,
      batch_size: 3,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
  end

  defmodule DefaultBatch do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 60_000,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
  end

  defmodule BatchStopsOnError do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 60_000,
      batch_size: 3,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:error, %{}} end}
  end

  defp insert_initializing_items(count) do
    EctoRepo.delete_all(Items)

    for _ <- 1..count do
      {:ok, _} = %Items{state: "initializing"} |> EctoRepo.insert()
    end
  end

  defp count_in_state(state),
    do: from(p in Items, where: p.state == ^state, select: count(p.id)) |> EctoRepo.one()

  defp wake_up_once(module) do
    {:ok, pid} = module.start_link()
    module.execute_now()
    :timer.sleep(300)
    GenServer.stop(pid)
  end

  test "STM with batch_size processes up to batch_size items per wake-up" do
    insert_initializing_items(5)

    wake_up_once(BatchOfThree)

    assert count_in_state("running") == 3
    assert count_in_state("initializing") == 2
  end

  test "STM with batch_size stops when no items are left" do
    insert_initializing_items(2)

    wake_up_once(BatchOfThree)

    assert count_in_state("running") == 2
    assert count_in_state("initializing") == 0
  end

  test "STM without batch_size processes one item per wake-up" do
    insert_initializing_items(3)

    wake_up_once(DefaultBatch)

    assert count_in_state("running") == 1
    assert count_in_state("initializing") == 2
  end

  test "STM with batch_size stops the batch on a failed transition" do
    insert_initializing_items(3)

    wake_up_once(BatchStopsOnError)

    assert count_in_state("running") == 0
    assert count_in_state("initializing") == 3
    # Only the first item was taken; the failed exit leaves it in scheduling.
    in_scheduling =
      from(p in Items, where: p.in_scheduling == true, select: count(p.id)) |> EctoRepo.one()

    assert in_scheduling == 1
  end

  defmodule BatchWithTimeBudget do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 60_000,
      batch_size: 10,
      batch_budget_ms: 100,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_) do
      :timer.sleep(60)
      {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
    end
  end

  test "STM with batch_size stops taking items once the time budget is spent" do
    insert_initializing_items(10)

    {:ok, pid} = BatchWithTimeBudget.start_link()
    BatchWithTimeBudget.execute_now()
    # Without the budget all 10 items (~600ms) would be processed by now.
    :timer.sleep(1_000)
    GenServer.stop(pid)

    running = count_in_state("running")
    assert running >= 1
    assert running <= 4
    assert count_in_state("initializing") == 10 - running
  end

  defmodule BatchIndexRecorder do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 60_000,
      batch_size: 3,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def enter_scheduling(params) do
      Agent.update(:batch_index_log, &[Map.get(params, :batch_index) | &1])
      super(params)
    end

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
  end

  test "STM passes the position in the batch to enter_scheduling" do
    insert_initializing_items(5)
    {:ok, _} = Agent.start_link(fn -> [] end, name: :batch_index_log)

    wake_up_once(BatchIndexRecorder)

    assert :batch_index_log |> Agent.get(& &1) |> Enum.reverse() == [0, 1, 2]
  end

  defmodule BatchConnectionProbe do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 60_000,
      batch_size: 3,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count]

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    # The test pool has a single connection. If the batch kept it checked out
    # between items, this query from another process could not get it.
    def scheduling_handler(_) do
      other_process_query =
        fn -> EctoRepo.query("SELECT 1") end
        |> Task.async()
        |> Task.await(5_000)

      Agent.update(:batch_conn_log, &[{EctoRepo.in_transaction?(), other_process_query} | &1])
      {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
    end
  end

  test "STM batch does not hold a DB connection between items" do
    insert_initializing_items(3)
    {:ok, _} = Agent.start_link(fn -> [] end, name: :batch_conn_log)

    wake_up_once(BatchConnectionProbe)

    log = Agent.get(:batch_conn_log, & &1)
    assert length(log) == 3

    Enum.each(log, fn {in_transaction?, other_process_query} ->
      refute in_transaction?
      assert {:ok, %{rows: [[1]]}} = other_process_query
    end)

    assert count_in_state("running") == 3
  end
end
