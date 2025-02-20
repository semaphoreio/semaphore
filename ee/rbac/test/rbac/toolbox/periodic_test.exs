defmodule Rbac.Toolbox.PeriodicTest do
  use ExUnit.Case, async: true

  def naptime, do: 100

  defmodule State do
    use GenServer

    def init(_opts) do
      {:ok, %{value: 0}}
    end

    def start_link do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    def handle_cast({:inc, value}, state) do
      {:noreply, Map.put(state, :value, value)}
    end

    def handle_call(:value, _from, state) do
      {:reply, state[:value] || 0, state}
    end
  end

  defmodule PeriodicModule do
    use Rbac.Toolbox.Periodic

    def init(_opts) do
      super(%{
        name: "test_periodic_worker",
        naptime: Rbac.Toolbox.PeriodicTest.naptime(),
        timeout: 2 * Rbac.Toolbox.PeriodicTest.naptime()
      })
    end

    def perform(_args \\ nil) do
      cur_value = value()
      GenServer.cast(State, {:inc, cur_value + 1})

      if rem(cur_value, 2) == 0 do
        perform_now()
      end
    end

    def value do
      GenServer.call(State, :value)
    end
  end

  describe "PeriodicModule behavior" do
    setup do
      {:ok, periodic} = PeriodicModule.start_link()
      {:ok, state} = State.start_link()

      on_exit(fn ->
        Process.exit(periodic, :kill)
        Process.exit(state, :kill)
      end)

      {:ok, %{}}
    end

    test "periodic execution increases value" do
      # perform will be called 5 times at t, t+100ms, .., t+400ms
      # perform increases state by 1 and if the state is even, it calls perform_now
      # so in the case we start with even state it will be increased by 10, after 5 calls
      # if we start with odd state it will be increased by 9
      reps = 5
      :timer.sleep(div(naptime(), 2))
      cur_value = PeriodicModule.value()
      :timer.sleep(reps * naptime() - 1)
      new_value = PeriodicModule.value()
      assert new_value == reps * 2 - rem(cur_value, 2)
    end
  end
end
