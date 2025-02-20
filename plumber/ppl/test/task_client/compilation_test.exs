defmodule Ppl.TaskClient.CompilationTest do
  use Ppl.IntegrationCase, async: false

  import Mock

  alias Ppl.TaskClient
  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Test.Support.RequestFactory

  @url_env_name "INTERNAL_API_URL_TASK"

  # Schedule

  test "when URL is invalid in schedule call => timeout occures" do
    old_env = System.get_env(@url_env_name)
    System.put_env(@url_env_name, "invalid_url:12345")

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

    assert {:error, message} = TaskClient.Compilation.start(ppl_req, pfcs, settings)
    assert {:timeout, _time_to_wait} = message

    System.put_env(@url_env_name, old_env)
  end

  test "when time-out occures in schedule call => error is returned" do
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

    with_mock TaskApiClient, schedule: &mocked_timeout(&1, &2, &3) do
      assert {:error, message} = TaskClient.Compilation.start(ppl_req, pfcs, settings)
      assert {:timeout, _time_to_wait} = message
    end
  end

  @tag :integration
  test "when schedule is called => gRPC server response is processed correctly" do
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

    assert {:ok, _task_id} = TaskClient.Compilation.start(ppl_req, pfcs, settings)
  end

  @tag :integration
  test "when settings are missing => error is returned" do
    ppl_req = %{
      request_args: RequestFactory.schedule_args(%{}, :local),
      source_args: %{},
      id: UUID.uuid4(),
      wf_id: UUID.uuid4()
    }

    pfcs = :undefined
    settings = %{}

    assert {:error, {:malformed, message}} = TaskClient.Compilation.start(ppl_req, pfcs, settings)
    assert message =~ "Machine type and OS image for initialization job are not defined"
  end

  def mocked_timeout(_arg_1, _arg_2, _arg_3) do
    :timer.sleep(10_000)
    :ok
  end
end
