defmodule Ppl.E2E.LooperExecuteNow.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions
  alias InternalApi.Plumber.Pipeline.Result
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Block.Tasks.Model.TasksQueries
  alias Block.Tasks.TaskEventsConsumer
  alias InternalApi.Task.TaskFinished
  alias Util.Proto

  setup do
    Test.Helpers.truncate_db()

    purge_queue("finished")

    {:ok, %{}}
  end

  def purge_queue(queue) do
    {:ok, connection} = System.get_env("RABBITMQ_URL") |> AMQP.Connection.open()
    queue_name = "block.#{queue}"
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.declare(channel, queue_name, durable: true)

    AMQP.Queue.purge(channel, queue_name)

    AMQP.Connection.close(connection)
  end

  @tag :integration
  test "termination is optimized with execute_now() looper calls" do
    ppl_originial_env = Application.get_all_env(:ppl)
    block_originial_env = Application.get_all_env(:block)

    postpone_all_loopers()

    loopers = Test.Helpers.start_all_loopers()
    assert {:ok, pid} = TaskEventsConsumer.start_link()

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_basic", "file_name" => "non-default-branch.yml",
        "label" => "master", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "running", 2_000)

    task_id = wait_for_task_scheduling(ppl_id, 0)

    assert {:ok, message} = Actions.terminate(%{"ppl_id" => ppl_id, "requester_id" => ppl_id})
    assert message == "Pipeline termination started."

    assert {:ok, _ppl_blk} =
      Test.Helpers.assert_finished_for_less_than(
        __MODULE__, :wait_for_ppl_block_state, [ppl_id, 0, "stopping"], 500)

    send_task_done_rabbit_msg(task_id)

    assert {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 500)
    assert ppl.result == "stopped"

    GenServer.stop(pid)
    Test.Helpers.stop_all_loopers(loopers)

    reset_app_env(:ppl, ppl_originial_env)
    reset_app_env(:block, block_originial_env)
  end

  @tag :integration
  test "All looper have set execut_now() call for next step on state transition" do
    ppl_originial_env = Application.get_all_env(:ppl)
    block_originial_env = Application.get_all_env(:block)

    postpone_all_loopers()

    loopers = Test.Helpers.start_all_loopers()
    assert {:ok, pid} = TaskEventsConsumer.start_link()

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_basic", "file_name" => "non-default-branch.yml",
        "label" => "master", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "running", 2_000)

    0..1 |> Enum.map(fn block_index ->
      ppl_id
      |> wait_for_task_scheduling(block_index)
      |> send_task_done_rabbit_msg()
    end)

    assert {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 500)
    assert ppl.result == "passed"

    GenServer.stop(pid)
    Test.Helpers.stop_all_loopers(loopers)

    reset_app_env(:ppl, ppl_originial_env)
    reset_app_env(:block, block_originial_env)
  end

  defp wait_for_task_scheduling(ppl_id, index) do
    assert {:ok, ppl_blk} =
      Test.Helpers.assert_finished_for_less_than(
        __MODULE__, :wait_for_ppl_block_state, [ppl_id, index, "running"], 500)

    assert {:ok, task} =
      Test.Helpers.assert_finished_for_less_than(
          __MODULE__, :wait_for_task_state, [ppl_blk.block_id, "running"], 500)

    task.task_id
  end

  def wait_for_ppl_block_state(ppl_id, index, desired_state) do
    :timer.sleep 100

    assert {:ok, ppl_blk} = PplBlocksQueries.get_by_id_and_index(ppl_id, index)

    if ppl_blk.state == desired_state do
      ppl_blk
    else
      wait_for_ppl_block_state(ppl_id, index, desired_state)
    end
  end

  def wait_for_task_state(block_id, desired_state) do
    :timer.sleep 100

    assert {:ok, task} = TasksQueries.get_by_id(block_id)

    if task.state == desired_state do
      task
    else
      wait_for_task_state(block_id, desired_state)
    end
  end

  defp send_task_done_rabbit_msg(task_id) do
    event = Proto.deep_new!(TaskFinished, %{task_id: task_id})
    encoded = TaskFinished.encode(event)
    Tackle.publish(encoded, exchange_params())
  end

  defp exchange_params() do
    %{url: System.get_env("RABBITMQ_URL"), exchange: "task_state_exchange",
      routing_key: "finished"}
  end

  defp postpone_all_loopers() do
    Application.put_env(:ppl, :general_looper_cooling_time_sec, 1_000)
    Application.put_env(:ppl, :ppl_initializing_ct, 1_000)
    Application.put_env(:ppl, :ppl_pending_ct, 1_000)
    Application.put_env(:ppl, :ppl_blk_initializing_ct, 1_000)
    Application.put_env(:ppl, :ppl_blk_waiting_ct, 1_000)
    Application.put_env(:ppl, :ppl_sub_init_created_ct, 1_000)
    Application.put_env(:ppl, :ppl_sub_init_regular_init_ct, 1_000)

    Application.put_env(:ppl, :general_sleeping_period_ms, 1_000_000)
    Application.put_env(:ppl, :ppl_pending_sp, 1_000_000)

    Application.put_env(:block, :general_looper_cooling_time_sec, 1_000)
    Application.put_env(:block, :blk_initializing_ct, 1_000)
    Application.put_env(:block, :task_pending_ct, 1_000)
    Application.put_env(:block, :general_sleeping_period_ms, 1_000_000)
  end

  defp reset_app_env(app, envs) do
    envs |> Enum.map(fn {key, value} ->
      Application.put_env(app, key, value)
    end)
  end
end
