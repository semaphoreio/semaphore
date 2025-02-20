defmodule Gofer.PlumberClient.Test do
  use ExUnit.Case

  alias Gofer.PlumberClient

  @grpc_port 50056

  setup_all do
    GRPC.Server.start(Test.MockPlumberService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockPlumberService)
    end)

    {:ok, %{}}
  end

  # ScheduleExtension

  test "send valid schedule request and receive valid test response" do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    params = %{
      ppl_id: UUID.uuid4(),
      file_path: "./deployments/stg.yml",
      request_token: UUID.uuid4(),
      prev_ppl_artefact_ids: [UUID.uuid4(), UUID.uuid4()],
      env_variables: [%{"name" => "A", "value" => "a"}, %{"name" => "B", "value" => "b"}],
      secret_names: ["DTabcd1234ef56"],
      promoted_by: "123",
      auto_promoted: false
    }

    assert {:ok, id} = PlumberClient.schedule_pipeline(params)
    assert {:ok, _} = UUID.info(id)
  end

  test "bad param schedule response from plumber service produces error" do
    use_test_plumber_service()
    test_plumber_service_schedule_response("bad_param")

    params = %{
      ppl_id: UUID.uuid4(),
      file_path: "./deployments/stg.yml",
      request_token: UUID.uuid4(),
      prev_ppl_artefact_ids: [UUID.uuid4(), UUID.uuid4()],
      env_variables: [%{"name" => "A", "value" => "a"}, %{"name" => "B", "value" => "b"}],
      secret_names: ["DTabcd1234ef56"],
      promoted_by: "123",
      auto_promoted: false
    }

    assert {:error, response} = PlumberClient.schedule_pipeline(params)
    assert response == {:bad_param, "Error"}
  end

  test "schedule returns error when it is not possible to connect to plumber service" do
    use_non_existing_plumber_service()

    params = %{
      ppl_id: UUID.uuid4(),
      file_path: "./deployments/stg.yml",
      request_token: UUID.uuid4(),
      prev_ppl_artefact_ids: [UUID.uuid4(), UUID.uuid4()],
      env_variables: [%{"name" => "A", "value" => "a"}, %{"name" => "B", "value" => "b"}],
      secret_names: ["DTabcd1234ef56"],
      promoted_by: "123",
      auto_promoted: false
    }

    assert {:error, _} = PlumberClient.schedule_pipeline(params)
  end

  test "schedule correctly timeouts if plumber service takes to long to respond" do
    use_test_plumber_service()
    test_plumber_service_schedule_response("timeout")

    params = %{
      ppl_id: UUID.uuid4(),
      file_path: "./deployments/stg.yml",
      request_token: UUID.uuid4(),
      prev_ppl_artefact_ids: [UUID.uuid4(), UUID.uuid4()],
      env_variables: [%{"name" => "A", "value" => "a"}, %{"name" => "B", "value" => "b"}],
      secret_names: ["DTabcd1234ef56"],
      promoted_by: "123",
      auto_promoted: false
    }

    assert {:error, _} = PlumberClient.schedule_pipeline(params)
  end

  # Describe

  test "send valid describe request and receive valid response" do
    use_test_plumber_service()

    ppl_id = UUID.uuid4()

    test_plumber_service_describe_response("passed")
    assert {:ok, "done", "passed", "", _done_at} = PlumberClient.describe(ppl_id)

    test_plumber_service_describe_response("failed")
    assert {:ok, "done", "failed", "test", _done_at} = PlumberClient.describe(ppl_id)
  end

  test "bad param describe response from plumber service produces error" do
    use_test_plumber_service()
    test_plumber_service_describe_response("bad_param")

    ppl_id = UUID.uuid4()

    assert {:error, response} = PlumberClient.describe(ppl_id)
    assert response == {:bad_param, "Error"}
  end

  test "limit exceeded describe response from plumber service produces error" do
    use_test_plumber_service()
    test_plumber_service_describe_response("limit_exceeded")

    ppl_id = UUID.uuid4()

    assert {:error, response} = PlumberClient.describe(ppl_id)
    assert response == :limit_exceeded
  end

  test "describe returns error when it is not possible to connect to plumber service" do
    use_non_existing_plumber_service()

    ppl_id = UUID.uuid4()

    assert {:error, _} = PlumberClient.describe(ppl_id)
  end

  test "describe correctly timeouts if plumber service takes to long to respond" do
    use_test_plumber_service()
    test_plumber_service_describe_response("timeout")

    ppl_id = UUID.uuid4()

    assert {:error, _} = PlumberClient.describe(ppl_id)
  end

  defp use_test_plumber_service(),
    do: Application.put_env(:gofer, :plumber_grpc_url, "localhost:#{inspect(@grpc_port)}")

  defp use_non_existing_plumber_service(),
    do: Application.put_env(:gofer, :plumber_grpc_url, "something:12345")

  defp test_plumber_service_schedule_response(value),
    do: Application.put_env(:gofer, :test_plumber_service_schedule_response, value)

  defp test_plumber_service_describe_response(value),
    do: Application.put_env(:gofer, :test_plumber_service_describe_response, value)
end
