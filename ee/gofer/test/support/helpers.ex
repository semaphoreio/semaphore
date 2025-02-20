defmodule Test.Helpers do
  import ExUnit.Assertions, only: [assert: 1]

  def use_test_plumber_service(grpc_port),
    do: Application.put_env(:gofer, :plumber_grpc_url, "localhost:#{inspect(grpc_port)}")

  def test_plumber_service_schedule_response(value),
    do: Application.put_env(:gofer, :test_plumber_service_schedule_response, value)

  def assert_finished_for_less_than(module, fun, args, timeout) do
    task = Task.async(module, fun, args)

    result = Task.yield(task, timeout)
    Task.shutdown(task)

    assert {:ok, _response} = result
  end

  def entity_processed?(module, fun, args) do
    :timer.sleep(200)

    assert {:ok, entity} = Kernel.apply(module, fun, args)

    case entity.processed do
      true -> :pass
      false -> entity_processed?(module, fun, args)
    end
  end
end
