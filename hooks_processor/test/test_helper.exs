formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(formatters: formatters)
ExUnit.start(capture_log: true)

GrpcMock.defmock(AdminServiceMock, for: InternalApi.Plumber.Admin.Service)
GrpcMock.defmock(WorkflowServiceMock, for: InternalApi.PlumberWF.WorkflowService.Service)
GrpcMock.defmock(ProjectHubServiceMock, for: InternalApi.Projecthub.ProjectService.Service)
GrpcMock.defmock(BranchServiceMock, for: InternalApi.Branch.BranchService.Service)
GrpcMock.defmock(UserServiceMock, for: InternalApi.User.UserService.Service)
GrpcMock.defmock(RepositoryServiceMock, for: InternalApi.Repository.RepositoryService.Service)
GrpcMock.defmock(RBACServiceMock, for: InternalApi.RBAC.RBAC.Service)

defmodule Test.Helpers do
  use ExUnit.Case

  def truncate_db do
    assert {:ok, _} = Ecto.Adapters.SQL.query(HooksProcessor.EctoRepo, "truncate table workflows;")
  end

  def wait_for_worker_to_finish(pid, timeout \\ 5_000) do
    assert_finished_for_less_than(__MODULE__, :check_if_worker_is_done, [pid], timeout)
  end

  def assert_finished_for_less_than(module, fun, args, timeout) do
    task = Task.async(module, fun, args)

    result = Task.yield(task, timeout)
    Task.shutdown(task)

    assert {:ok, _response} = result
  end

  def check_if_worker_is_done(pid) do
    :timer.sleep(100)

    if Process.alive?(pid) do
      check_if_worker_is_done(pid)
    else
      true
    end
  end

  def ensure_unregistered(name) do
    case Process.whereis(name) do
      pid when is_pid(pid) -> Process.unregister(name)
      nil -> :ok
    end
  end

  def wait_until_stopped(names) when is_list(names) do
    names |> Enum.each(&wait_until_stopped/1)
  end

  def wait_until_stopped(app) when is_atom(app) do
    case Application.started_applications() |> Enum.any?(fn {name, _, _} -> name == app end) do
      true ->
        :timer.sleep(100)
        wait_until_stopped(app)

      false ->
        :ok
    end
  end

  def wait_until_stopped(name) do
    case Process.whereis(name) do
      pid when is_pid(pid) ->
        :timer.sleep(100)
        wait_until_stopped(name)

      nil ->
        :ok
    end
  end
end
