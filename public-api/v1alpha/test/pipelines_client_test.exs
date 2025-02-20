defmodule PipelinesAPI.PipelinesClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.PipelinesClient
  alias InternalApi.Plumber.DescribeTopologyResponse.Block
  alias InternalApi.Plumber.Pipeline

  test "request description of pipeline from pipelines service and get valid response" do
    user_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: UUID.uuid4(), branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    assert {:ok, _} = UUID.info(pipeline.id)

    :timer.sleep(5_000)

    assert {:ok, %{pipeline: pipeline, blocks: blocks}} =
             PipelinesClient.describe(pipeline.id, %{"detailed" => "true"})

    assert %Pipeline{} = pipeline
    assert is_list(blocks)
  end

  test "describe rpc call returns internal error when it cann't connect to Pipelines service" do
    System.put_env("PPL_GRPC_URL", "something:12345")

    ppl_id = UUID.uuid4()

    assert {:error, {:internal, message}} =
             PipelinesClient.describe(ppl_id, %{"detailed" => "false"})

    assert message == "Internal error"

    System.put_env("PPL_GRPC_URL", "127.0.0.1:50052")
  end

  test "request termination of pipeline from pipelines service and get valid response" do
    user_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: UUID.uuid4(), branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    assert {:ok, _} = UUID.info(pipeline.id)

    :timer.sleep(3_000)

    assert {:ok, message} = PipelinesClient.terminate(pipeline.id)
    assert message == "Pipeline termination started."
  end

  test "terminate rpc call returns internal error when it cann't connect to Pipelines service" do
    System.put_env("PPL_GRPC_URL", "something:12345")

    ppl_id = UUID.uuid4()
    assert {:error, {:internal, message}} = PipelinesClient.terminate(ppl_id)
    assert message == "Internal error"

    System.put_env("PPL_GRPC_URL", "127.0.0.1:50052")
  end

  test "request list of pipeline from pipelines service and get valid response" do
    ppls_ids = prepare_ppls(8, "list-test-1")
    params = list_params("list-test-1", "2", "4")
    assert {:ok, page} = PipelinesClient.list(params)
    assert %Scrivener.Page{entries: pipelines_list} = page
    assert is_list(pipelines_list)

    # oldest four ppl's should be on the second page
    included = ppls_ids |> Enum.slice(0..3)
    excluded = ppls_ids |> Enum.slice(4..8)

    assert list_result_contains?(pipelines_list, included)
    refute list_result_contains?(pipelines_list, excluded)
  end

  test "list rpc call returns internal error when it cann't connect to Pipelines service" do
    System.put_env("PPL_GRPC_URL", "something:12345")

    params = list_params("list-test-1", "1")
    assert {:error, {:internal, message}} = PipelinesClient.list(params)
    assert message == "Internal error"

    System.put_env("PPL_GRPC_URL", "127.0.0.1:50052")
  end

  test "list with wf_id and get valid response" do
    user_id = UUID.uuid4()
    project_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: project_id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    assert {:ok, page} =
             PipelinesClient.list(%{"project_id" => project_id, "wf_id" => workflow.id})

    %Scrivener.Page{
      entries: [%{ppl_id: id}],
      page_number: 1,
      page_size: 30,
      total_entries: 1,
      total_pages: 1
    } = page

    assert id == pipeline.id
  end

  defp prepare_ppls(num, project_id) do
    user_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: project_id, branch_id: UUID.uuid4()}

    Range.new(0, num - 1)
    |> Enum.map(fn n ->
      workflow = Support.Stubs.Workflow.create(hook, user_id)

      pipeline =
        Support.Stubs.Pipeline.create_initial(workflow,
          branch_name: "non-default-branch",
          created_at:
            Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()) + n)
        )

      pipeline.id
    end)
  end

  defp list_params(project_id, page, page_size \\ "5") do
    %{
      "project_id" => project_id,
      "branch_name" => "non-default-branch",
      "page" => page,
      "page_size" => page_size
    }
  end

  defp list_result_contains?(results, ppls) do
    Enum.reduce(ppls, true, fn ppl_id, acc ->
      case acc do
        false -> false
        true -> ppl_id_in_results?(ppl_id, results)
      end
    end)
  end

  defp ppl_id_in_results?(ppl_id, results),
    do: Enum.find(results, nil, fn %{ppl_id: id} -> id == ppl_id end) != nil

  test "request get_project_id from pipelines service and get valid response" do
    user_id = UUID.uuid4()
    expected_project_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: expected_project_id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    assert {:ok, _} = UUID.info(pipeline.id)
    assert {:ok, project_id} = PipelinesClient.get_project_id(pipeline.id)
    assert project_id == expected_project_id
  end

  test "get_project_id rpc call returns internal error when it can't connect to Pipelines service" do
    System.put_env("PPL_GRPC_URL", "something:12345")

    ppl_id = UUID.uuid4()
    assert {:error, {:internal, message}} = PipelinesClient.get_project_id(ppl_id)
    assert message == "Internal error"

    System.put_env("PPL_GRPC_URL", "127.0.0.1:50052")
  end

  test "describe_topology rpc call returns valid response" do
    hook = %{id: UUID.uuid4(), project_id: UUID.uuid4(), branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    _ =
      Support.Stubs.Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"]
      })

    assert {:ok, _} = UUID.info(pipeline.id)
    assert {:ok, _} = PipelinesClient.describe(pipeline.id, %{})
    assert {:ok, blocks} = PipelinesClient.describe_topology(pipeline.id)

    assert blocks == [
             %Block{jobs: ["First job"], name: "Block #1", dependencies: []}
           ]
  end

  test "describe_topology rpc call returns internal error" do
    System.put_env("PPL_GRPC_URL", "something:12345")

    ppl_id = UUID.uuid4()
    assert {:error, {:internal, message}} = PipelinesClient.describe_topology(ppl_id)
    assert message == "Internal error"

    System.put_env("PPL_GRPC_URL", "127.0.0.1:50052")
  end

  test "request yaml validation without scheduling for valid yaml and get valid response" do
    params = validate_params(:valid, "")
    assert {:ok, response} = PipelinesClient.validate_yaml(params)
    assert Map.get(response, :message) == "YAML definition is valid."
    assert Map.get(response, :pipeline_id) == ""
  end

  test "request scheduling with valid yaml and ppl_id and get valid response" do
    hook = %{id: UUID.uuid4(), project_id: UUID.uuid4(), branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    assert {:ok, _} = UUID.info(pipeline.id)

    params = validate_params(:valid, pipeline.id)
    assert {:ok, response} = PipelinesClient.validate_yaml(params)
    assert Map.get(response, :message) == "YAML definition is valid."
    assert {:ok, _} = Map.get(response, :pipeline_id) |> UUID.info()
  end

  test "request yaml validation without scheduling for invalid yaml and get valid response" do
    params = validate_params(:invalid, "")
    assert {:error, {:user, message}} = PipelinesClient.validate_yaml(params)
    assert message == "{:malformed, {:expected_map, \"Asdfghjkl\"}}"
  end

  defp validate_params(yaml_validity, ppl_id) do
    %{
      "yaml_definition" => get_yaml_def(yaml_validity),
      "pipeline_id" => ppl_id
    }
  end

  defp get_yaml_def(:valid) do
    """
    version: "v1.0"
    name: basic test
    agent:
      machine:
        type: e1-standard-2
        os_image: ubuntu1804
    blocks:
      - task:
          jobs:
            - commands:
                - echo foo
    """
  end

  defp get_yaml_def(:invalid), do: "Asdfghjkl"

  # Version

  test "request version from pipelines service and get valid response" do
    assert {:ok, response} = PipelinesClient.version()
    assert valid_version_string(response)
  end

  test "version rpc call returns internal error when it can't connect to Pipelines service" do
    System.put_env("PPL_GRPC_URL", "something:12345")

    assert {:error, {:internal, message}} = PipelinesClient.version()
    assert message == "Internal error"

    System.put_env("PPL_GRPC_URL", "127.0.0.1:50052")
  end

  defp valid_version_string(version) do
    with true <- is_binary(version),
         parts <- String.split(version, "."),
         3 <- length(parts) do
      true
    else
      _ -> false
    end
  end
end
