defmodule Rbac.Utils.Log do
  require Logger

  def observe(name, f) do
    Watchman.benchmark(name, fn ->
      try do
        Logger.info("Service #{name} - Started")
        result = f.()
        Logger.info("Service #{name} - Finished")

        Watchman.increment({name, ["OK"]})
        result
      rescue
        e ->
          Logger.error("Service #{name} - Exited with an error: #{inspect(e)}")
          Watchman.increment({name, ["ERROR"]})
          reraise e, __STACKTRACE__
      end
    end)
  end
end
