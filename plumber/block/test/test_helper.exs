Code.require_file("test/support/grpc_server_helper.ex")

formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end
ExUnit.configure(
  exclude: [integration: true],
  capture_log: true,
  formatters: formatters
)
ExUnit.start()

GrpcMock.defmock(RepoHubMock, for: InternalApi.Repository.RepositoryService.Service)

defmodule Test.Helpers do
  use ExUnit.Case


  def assert_finished_for_less_than(module, fun, args, timeout) do
    task = Task.async(module, fun, args)

    result = Task.yield(task, timeout)

    assert {:ok, _response} = result
  end

  def wait_for_block_state(block_id, desired_state, timeout \\ 1_000) do
    Test.Helpers.assert_finished_for_less_than(
      __MODULE__, :do_wait_for_block_state, [block_id, desired_state], timeout)
  end

  def do_wait_for_block_state(block_id, desired_state) do
    :timer.sleep 100

    {:ok, status = %{state: state}} = Block.status(block_id)

    if state == desired_state do
      status
    else
      do_wait_for_block_state(block_id, desired_state)
    end
  end

  def start_loopers() do
    []
    # Blocks Loopers
    |> Enum.concat([Block.Blocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.StoppingState.start_link()])
    # Task Loopers
    |> Enum.concat([Block.Tasks.STMHandler.PendingState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.StoppingState.start_link()])
  end

  def stop_loopers(loopers) do
    loopers |> Enum.map(fn({_resp, pid}) -> GenServer.stop(pid) end)
  end
end
