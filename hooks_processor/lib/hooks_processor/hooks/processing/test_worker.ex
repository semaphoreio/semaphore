defmodule HooksProcessor.Hooks.Processing.TestWorker do
  @moduledoc """
  Worker used in test env to test Supervisor
  """
  use GenServer, restart: :transient

  def start_link(id) do
    name = {:via, Registry, {WorkersRegistry, "test_worker-#{id}"}}
    GenServer.start_link(__MODULE__, id, name: name)
  end

  def init(id) do
    send(self(), :testing_func)

    {:ok, %{id: id}}
  end

  def handle_info(:testing_func, state) do
    func = Application.get_env(:hooks_processor, :test_worker_func)

    func.(state)
  end
end
