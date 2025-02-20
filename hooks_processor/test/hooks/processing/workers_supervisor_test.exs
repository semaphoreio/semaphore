defmodule HooksProcessor.Hooks.Processing.WorkersSupervisor.Test do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Processing.WorkersSupervisor

  setup do
    start_supervised!(WorkersSupervisor)

    :ok
  end

  defp test_func(exit_type) do
    fn state ->
      assert %{id: "hook_id"} == state
      :timer.sleep(1_000)
      {:stop, exit_type, state}
    end
  end

  test "WorkersSupervisor starts worker processes given an unique hook id" do
    func = test_func(:normal)
    Application.put_env(:hooks_processor, :test_worker_func, func)

    assert {:ok, _pid} = WorkersSupervisor.start_worker_for_webhook("hook_id")

    assert WorkersSupervisor.count_children() ==
             %{active: 1, specs: 1, supervisors: 0, workers: 1}
  end

  test "WorkersSupervisor start_worker actions is idempotent" do
    func = test_func(:normal)
    Application.put_env(:hooks_processor, :test_worker_func, func)

    assert {:ok, pid_1} = WorkersSupervisor.start_worker_for_webhook("hook_id")

    assert WorkersSupervisor.count_children() ==
             %{active: 1, specs: 1, supervisors: 0, workers: 1}

    assert {:ok, pid_2} = WorkersSupervisor.start_worker_for_webhook("hook_id")

    assert WorkersSupervisor.count_children() ==
             %{active: 1, specs: 1, supervisors: 0, workers: 1}

    assert pid_1 == pid_2
  end

  test "when child exits with :normal it is not restarted" do
    func = test_func(:normal)
    Application.put_env(:hooks_processor, :test_worker_func, func)

    assert {:ok, _pid} = WorkersSupervisor.start_worker_for_webhook("hook_id")

    assert WorkersSupervisor.count_children() ==
             %{active: 1, specs: 1, supervisors: 0, workers: 1}

    :timer.sleep(1_500)

    assert WorkersSupervisor.count_children() ==
             %{active: 0, specs: 0, supervisors: 0, workers: 0}
  end

  test "when child exits with something other than :normal reason, it is restarted" do
    func = test_func(:restart)
    Application.put_env(:hooks_processor, :test_worker_func, func)

    assert {:ok, _pid} = WorkersSupervisor.start_worker_for_webhook("hook_id")

    assert WorkersSupervisor.count_children() ==
             %{active: 1, specs: 1, supervisors: 0, workers: 1}

    :timer.sleep(1_500)

    assert WorkersSupervisor.count_children() ==
             %{active: 1, specs: 1, supervisors: 0, workers: 1}
  end
end
