defmodule Ppl.Grpc.InFlightCounter.Test do
  use ExUnit.Case

  alias Ppl.Grpc.InFlightCounter

  test "counter is decremented after process termination" do
    start_supervised({InFlightCounter, type: :a, limit: 5})

    assert InFlightCounter.count(:a) == 0

    this = self()
    pid = spawn(fn ->
      InFlightCounter.register(:a)
      send(this, :registered)
      :timer.sleep(:infinity)
    end)

    wait_for(:registered)

    assert InFlightCounter.count(:a) == 1

    Process.exit(pid, :shutdown)
    :timer.sleep(300)
    assert InFlightCounter.count(:a) == 0
  end

  test "return :continue or :resource_exhausted" do
    start_supervised({InFlightCounter, type: :a, limit: 3})

    spawn_link(__MODULE__, :assert_register_response, [self(), :a, :accept])
    wait_for(:registered)
    spawn_link(__MODULE__, :assert_register_response, [self(), :a, :accept])
    wait_for(:registered)

    assert_raise(GRPC.RPCError, fn -> InFlightCounter.register(:a) end)
  end

  def assert_register_response(dest, type, expected_response) do
    assert InFlightCounter.register(type) == expected_response
    send(dest, :registered)
    :timer.sleep(:infinity)
  end

  defp wait_for(message) do
    receive do
      ^message -> :ok
    after
      2_000 -> :ok
    end
  end
end
