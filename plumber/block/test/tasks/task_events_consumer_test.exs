defmodule Block.Tasks.TaskEventsConsumer.Test do
  use ExUnit.Case

  import Mock
  import Ecto.Query

  alias Block.Tasks.STMHandler.RunningState, as: TasksRunningState
  alias Block.Tasks.STMHandler.StoppingState, as: TasksStoppingState
  alias Block.Tasks.TaskEventsConsumer
  alias InternalApi.Task.TaskFinished
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo
  alias Util.Proto

  setup  do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")
    purge_queue("finished")

    :ok
  end

  def purge_queue(queue) do
    {:ok, connection} = System.get_env("RABBITMQ_URL") |> AMQP.Connection.open()
    queue_name = "block.#{queue}"
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.declare(channel, queue_name, durable: true)

    AMQP.Queue.purge(channel, queue_name)

    AMQP.Connection.close(connection)
  end

  test "valid message is processed and running looper is triggerd" do
    id = get_id()
    event = Proto.deep_new!(TaskFinished, %{task_id: id})
    encoded = TaskFinished.encode(event)

    with_mock TasksRunningState,
              [execute_now_with_predicate: &(mocked_execute_now(&1, id))] do

      assert {:ok, pid} = TaskEventsConsumer.start_link()

      Tackle.publish(encoded, exchange_params())
      :timer.sleep(1_000)

      GenServer.stop(pid)
    end
  end

  test "valid message is processed and stopping looper is triggerd" do
    id = get_id()
    event = Proto.deep_new!(TaskFinished, %{task_id: id})
    encoded = TaskFinished.encode(event)

    with_mock TasksStoppingState,
              [execute_now_with_predicate: &(mocked_execute_now(&1, id))] do

      assert {:ok, pid} = TaskEventsConsumer.start_link()

      Tackle.publish(encoded, exchange_params())
      :timer.sleep(1_000)

      GenServer.stop(pid)
    end
  end

  defp get_id() do
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: %{},
                version: "v3.0", definition: %{}, hook_id: UUID.uuid4()}

    assert {:ok, blk_req} = BlockRequestsQueries.insert_request(request)

    event = %{block_id: blk_req.id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:build_request_id, UUID.uuid4())
      |> Map.put(:task_id, UUID.uuid4())

    assert {:ok, task} = %Tasks{} |> Tasks.changeset(event) |> Repo.insert()

    task.task_id
  end

  defp exchange_params() do
    %{url: System.get_env("RABBITMQ_URL"), exchange: "task_state_exchange",
      routing_key: "finished"}
  end

  defp mocked_execute_now(actual_fun, id) do
    expected_fun  = fn entity -> entity |> where(task_id: ^id) end
    expected_res = Tasks |> expected_fun.() |> Repo.one()
    actual_res =  Tasks |> actual_fun.() |> Repo.one()
    assert expected_res == actual_res
  end

end
