defmodule Ppl.Retention.Deleter.WorkerTest do
  use ExUnit.Case, async: false

  alias Ppl.Retention.Deleter.Worker
  alias Ppl.Retention.StateAgent

  setup do
    stop_if_running()
    start_supervised!(StateAgent)
    Worker.update_config(interval_ms: 60_000, batch_size: 10)
    Worker.resume()
    pid = start_supervised!(Worker)
    on_exit(fn -> stop_if_running() end)
    {:ok, pid: pid}
  end

  describe "pause/resume" do
    test "starts in running state" do
      assert Worker.status() == :running
      assert Worker.paused?() == false
    end

    test "pause sets status to paused" do
      :ok = Worker.pause()
      assert Worker.status() == :paused
      assert Worker.paused?() == true
    end

    test "resume sets status to running" do
      :ok = Worker.pause()
      :ok = Worker.resume()
      assert Worker.status() == :running
      assert Worker.paused?() == false
    end

    test "pause_for expires after duration" do
      :ok = Worker.pause_for(10)
      assert Worker.paused?() == true
      :timer.sleep(20)
      assert Worker.paused?() == false
    end
  end

  describe "config" do
    test "returns current configuration" do
      config = Worker.config()
      assert config.interval_ms == 60_000
      assert config.batch_size == 10
    end

    test "update_config changes configuration" do
      :ok = Worker.update_config(interval_ms: 5_000, batch_size: 50)
      config = Worker.config()
      assert config.interval_ms == 5_000
      assert config.batch_size == 50
    end

    test "update_config with partial options" do
      :ok = Worker.update_config(batch_size: 25)
      config = Worker.config()
      assert config.interval_ms == 60_000
      assert config.batch_size == 25
    end
  end

  defp stop_if_running do
    case Process.whereis(Worker) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end
end
