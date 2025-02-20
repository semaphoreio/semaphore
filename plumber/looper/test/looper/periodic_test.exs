defmodule Looper.PeriodicTest do
  use ExUnit.Case

  alias Looper.Periodic
  alias Util.Metrics

  defmodule Demo do
    use Looper.Periodic,
      period_ms: 200,
      metric_name: {"Demo.foo", [Metrics.dot2dash(__MODULE__)]},
      args: Application.get_env(:looper, :periodic_test_master)

    def recurring(args) do
      send(args)
    end

    def send({pid}) do
      :timer.sleep 16_200
      send pid, :started
    end
  end

  test "periodic is executed and timeout is set at 16_000" do
    Application.put_env(:looper, :periodic_test_master, {self()})
    Looper.PeriodicTest.Demo.start_link
    refute_receive(:started, 16_500)
    Looper.PeriodicTest.Demo.stop
  end

  defmodule ExecuteNowDemo do
    use Periodic,
      period_ms: 200,
      metric_name: {"Demo.foo", [Metrics.dot2dash(__MODULE__)]},
      args: Application.get_env(:looper, :periodic_test_master)

    def recurring(args), do: send(args)

    def send({pid}), do: send pid, :started
  end

  test "execute_now" do
    alias Looper.PeriodicTest.ExecuteNowDemo

    Application.put_env(:looper, :periodic_test_master, {self()})
    ExecuteNowDemo.start_link
    assert_receive(:started, 250)
    ExecuteNowDemo.execute_now
    assert_receive(:started, 30)
    assert_receive(:started, 250)
    ExecuteNowDemo.stop
  end
end
