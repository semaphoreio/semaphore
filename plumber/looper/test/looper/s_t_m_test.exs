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
end
