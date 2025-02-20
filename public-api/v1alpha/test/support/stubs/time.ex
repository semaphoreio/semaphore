defmodule Support.Stubs.Time do
  def init do
    Agent.start_link(fn -> 0 end, name: __MODULE__)
  end

  def now do
    Google.Protobuf.Timestamp.new(seconds: current())
  end

  def travel_back(time, callback) do
    Agent.update(__MODULE__, fn _ -> time end)

    res = callback.()

    Agent.update(__MODULE__, fn _ -> 0 end)

    res
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> 0 end)
  end

  defp current do
    drift = Agent.get(__MODULE__, fn t -> t end)

    t = DateTime.utc_now() |> DateTime.to_unix()

    t - drift
  end
end
