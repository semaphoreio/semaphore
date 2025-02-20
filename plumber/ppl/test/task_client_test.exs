defmodule Ppl.TaskClientTest do
  use ExUnit.Case, async: false

  import Mock

  alias Ppl.TaskClient
  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Test.Support.RequestFactory

  @url_env_name "INTERNAL_API_URL_TASK"

  # Describe
  test "when URL is invalid in describe call => timeout occures" do
    old_env = System.get_env(@url_env_name)
    System.put_env(@url_env_name, "invalid_url:12345")

    assert {:error, message} = TaskClient.describe("task_id_1")
    assert {:timeout, _time_to_wait} = message

    System.put_env(@url_env_name, old_env)
  end

  test "when time-out occures in describe call => error is returned" do
    with_mock TaskApiClient, describe: &mocked_timeout(&1, &2) do
      assert {:error, message} = TaskClient.describe("task_id_1")
      assert {:timeout, _time_to_wait} = message
    end
  end

  @tag :integration
  test "when describe is called => gRPC server response is processed correctly" do
    ppl_req = %{
      request_args: RequestFactory.schedule_args(%{}, :local),
      source_args: %{},
      id: UUID.uuid4(),
      wf_id: UUID.uuid4()
    }

    pfcs = :undefined

    settings = %{
      "plan_machine_type" => "e2-standard-4",
      "plan_os_image" => "ubuntu2004",
      "custom_machine_type" => "f1-standard-2",
      "custom_os_image" => "ubuntu2204"
    }

    assert {:ok, task_id} = TaskClient.Compilation.start(ppl_req, pfcs, settings)

    :timer.sleep(1_500)

    assert {:ok, "done", "passed"} == TaskClient.describe(task_id)
  end

  # Terminate

  test "when URL is invalid in terminate call => timeout occures" do
    old_env = System.get_env(@url_env_name)
    System.put_env(@url_env_name, "invalid_url:12345")

    assert {:error, message} = TaskClient.terminate("task_id_1")
    assert {:timeout, _time_to_wait} = message

    System.put_env(@url_env_name, old_env)
  end

  test "when time-out occures in terminate call => error is returned" do
    with_mock TaskApiClient, terminate: &mocked_timeout(&1, &2) do
      assert {:error, message} = TaskClient.terminate("task_id_1")

      assert {:timeout, _time_to_wait} = message
    end
  end

  @tag :integration
  test "when terminate is called => gRPC server response is processed correctly" do
    ppl_req = %{
      request_args: RequestFactory.schedule_args(%{}, :local),
      source_args: %{},
      id: UUID.uuid4(),
      wf_id: UUID.uuid4()
    }

    settings = %{
      "plan_machine_type" => "e2-standard-4",
      "plan_os_image" => "ubuntu2004",
      "custom_machine_type" => "f1-standard-2",
      "custom_os_image" => "ubuntu2204"
    }

    pfcs = :undefined

    assert {:ok, task_id} = TaskClient.Compilation.start(ppl_req, pfcs, settings)

    assert {:ok, message} = TaskClient.terminate(task_id)
    assert message == %{message: "Task marked for termination."}
  end

  def mocked_timeout(_arg_1, _arg_2) do
    :timer.sleep(5_000)
    :ok
  end

  def mocked_timeout(_arg_1, _arg_2, _arg_3) do
    :timer.sleep(5_000)
    :ok
  end
end
