defmodule GithubNotifier.Models.PeriodicTest do
  use ExUnit.Case

  alias GithubNotifier.Models.Periodic

  setup do
    Cachex.clear(:task_policy)

    :ok
  end

  test "returns the task's notification skip flags" do
    GrpcMock.stub(
      SchedulerMock,
      :describe,
      Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
    )

    assert %Periodic{} = periodic = Periodic.find("task-1")
    assert periodic.skip_scheduled_run_notifications == true
    assert periodic.skip_manual_run_notifications == false
  end

  test "caches a successful lookup" do
    GrpcMock.stub(
      SchedulerMock,
      :describe,
      Support.Factories.periodic_describe_response(skip_manual_run_notifications: true)
    )

    assert %Periodic{} = Periodic.find("task-1")

    GrpcMock.stub(SchedulerMock, :describe, fn _, _ -> raise "should not be called again" end)

    assert %Periodic{skip_manual_run_notifications: true} = Periodic.find("task-1")
  end

  test "caches a not-found lookup so a deleted task is not re-queried" do
    GrpcMock.stub(SchedulerMock, :describe, Support.Factories.periodic_not_found_response())

    assert Periodic.find("gone") == nil
    assert Cachex.get!(:task_policy, "gone") == :not_found
  end

  test "a cached not-found is answered without asking the scheduler again" do
    GrpcMock.stub(SchedulerMock, :describe, Support.Factories.periodic_not_found_response())

    assert Periodic.find("gone") == nil

    GrpcMock.stub(SchedulerMock, :describe, fn _, _ -> raise "should not be called again" end)

    assert Periodic.find("gone") == nil
  end

  test "caches a transport failure only briefly, so an outage does not cost a lookup per event" do
    GrpcMock.stub(SchedulerMock, :describe, fn _, _ -> raise "boom" end)

    assert Periodic.find("task-1") == nil
    assert Cachex.get!(:task_policy, "task-1") == :not_found

    {:ok, ttl} = Cachex.ttl(:task_policy, "task-1")
    assert ttl <= :timer.seconds(5)
  end
end
