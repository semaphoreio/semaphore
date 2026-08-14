defmodule GithubNotifier.Models.PeriodicTest do
  use ExUnit.Case

  alias GithubNotifier.Models.Periodic

  setup do
    Cachex.clear(:task_policy)

    :ok
  end

  defp describe_response(code, periodic \\ nil) do
    struct(InternalApi.PeriodicScheduler.DescribeResponse,
      status: struct(InternalApi.Status, code: code),
      periodic: periodic
    )
  end

  defp periodic(commit_status) do
    struct(InternalApi.PeriodicScheduler.Periodic,
      id: "periodic-1",
      commit_status: commit_status
    )
  end

  describe ".find" do
    test "returns the task policy on a successful describe" do
      GrpcMock.stub(SchedulerMock, :describe, describe_response(:OK, periodic(:NEVER)))

      assert %Periodic{id: "periodic-1", commit_status: :NEVER} = Periodic.find("periodic-1")
    end

    test "returns nil when the task is not found" do
      GrpcMock.stub(SchedulerMock, :describe, describe_response(:NOT_FOUND))

      assert Periodic.find("gone") == nil
    end

    test "caches successful lookups" do
      GrpcMock.stub(SchedulerMock, :describe, describe_response(:OK, periodic(:ALWAYS)))

      assert %Periodic{commit_status: :ALWAYS} = Periodic.find("periodic-1")

      GrpcMock.stub(SchedulerMock, :describe, fn _req, _stream ->
        raise "describe must not be called again for a cached task"
      end)

      assert %Periodic{commit_status: :ALWAYS} = Periodic.find("periodic-1")
    end

    test "does not cache failed lookups" do
      GrpcMock.stub(SchedulerMock, :describe, describe_response(:NOT_FOUND))
      assert Periodic.find("periodic-1") == nil

      GrpcMock.stub(SchedulerMock, :describe, describe_response(:OK, periodic(:NEVER)))
      assert %Periodic{commit_status: :NEVER} = Periodic.find("periodic-1")
    end
  end
end
