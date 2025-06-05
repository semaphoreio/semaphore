defmodule PipelinesAPI.PipelinesClient.RequestFormatter.Test do
  use ExUnit.Case

  alias PipelinesAPI.PipelinesClient.RequestFormatter

  alias InternalApi.Plumber.{
    DescribeRequest,
    TerminateRequest,
    ListRequest,
    GetProjectIdRequest,
    DescribeTopologyRequest,
    ValidateYamlRequest
  }

  # Describe

  test "form_describe_request() returns {:ok, request} when called with string param" do
    ppl_id = UUID.uuid4()
    params = %{"detailed" => "false"}

    assert {:ok, describe_request} = RequestFormatter.form_describe_request(ppl_id, params)
    assert %DescribeRequest{} = describe_request
  end

  test "form_describe_request() returns error when called with something other than string for ppl_id" do
    ppl_id = 123
    params = %{"detailed" => "false"}

    assert {:error, {:user, message}} = RequestFormatter.form_describe_request(ppl_id, params)
    assert message == "Parameter pipeline_id must be a string."
  end

  # Terminate

  test "form_terminate_request() returns {:ok, request} when called with string param" do
    params = UUID.uuid4()

    assert {:ok, terminate_request} = RequestFormatter.form_terminate_request(params)
    assert %TerminateRequest{} = terminate_request
  end

  test "form_terminate_request() returns error when called with something other than string" do
    params = 123

    assert {:error, {:user, message}} = RequestFormatter.form_terminate_request(params)
    assert message == "Parameter pipeline_id must be a string."
  end

  # List

  test "form_list_request() returns {:ok, request} when called with map with all params" do
    params = list_params()

    assert {:ok, list_request} = RequestFormatter.form_list_request(params)
    assert %ListRequest{} = list_request
  end

  test "form_list_request() accepts created after/before params" do
    now = DateTime.utc_now() |> DateTime.to_unix()
    in_the_past = now - :rand.uniform(60 * 60 * 24 * 30)

    params =
      list_params()
      |> Map.put("created_after", "#{in_the_past}")
      |> Map.put("created_before", "#{now}")

    assert {:ok, list_request} = RequestFormatter.form_list_request(params)

    assert %ListRequest{
             created_after: %Google.Protobuf.Timestamp{nanos: 0, seconds: ^in_the_past},
             created_before: %Google.Protobuf.Timestamp{nanos: 0, seconds: ^now}
           } = list_request
  end

  test "form_list_request() accepts done after/before params" do
    now = DateTime.utc_now() |> DateTime.to_unix()
    in_the_past = now - :rand.uniform(60 * 60 * 24 * 30)

    params =
      list_params()
      |> Map.put("done_after", "#{in_the_past}")
      |> Map.put("done_before", "#{now}")

    assert {:ok, list_request} = RequestFormatter.form_list_request(params)

    assert %ListRequest{
             done_after: %Google.Protobuf.Timestamp{nanos: 0, seconds: ^in_the_past},
             done_before: %Google.Protobuf.Timestamp{nanos: 0, seconds: ^now}
           } = list_request
  end

  test "form_list_request() returns error when called with map with misssing params" do
    params = list_params()

    [
      {"project_id", :optional},
      {"branch_name", :optional},
      {"page", :optional},
      {"page_size", :optional}
    ]
    |> Enum.map(fn {field_name, mode} ->
      test_query_param_is_required(params, field_name, mode)
    end)
  end

  defp test_query_param_is_required(params, field_name, mode) do
    params = Map.delete(params, field_name)

    case mode do
      :required ->
        assert {:error, {:user, message}} = RequestFormatter.form_list_request(params)
        assert message == "Missing required query parameter #{field_name}."

      :optional ->
        assert {:ok, list_request} = RequestFormatter.form_list_request(params)
        assert %ListRequest{} = list_request
    end
  end

  test "form_list_request() returns internal error when it is not called with map as a param" do
    params = "123"

    assert {:error, {:internal, message}} = RequestFormatter.form_list_request(params)
    assert message == "Internal error"
  end

  defp list_params() do
    %{
      "project_id" => UUID.uuid4(),
      "branch_name" => "master",
      "page" => 2,
      "page_size" => 35
    }
  end

  # Get Project Id

  test "form_get_project_id_request() returns {:ok, request} when called with string param" do
    params = UUID.uuid4()

    assert {:ok, get_project_id_request} = RequestFormatter.form_get_project_id_request(params)
    assert %GetProjectIdRequest{} = get_project_id_request
  end

  test "form_get_project_id_request() returns error when called with non string param" do
    params = 123

    assert {:error, {:user, message}} = RequestFormatter.form_get_project_id_request(params)
    assert message == "Parameter pipeline_id must be a string."
  end

  # DescribeTopology

  test "form_describe_topology_request() returns {:ok, request} when called with string param" do
    ppl_id = UUID.uuid4()

    assert {:ok, describe_topology_request} =
             RequestFormatter.form_describe_topology_request(ppl_id)

    assert %DescribeTopologyRequest{} = describe_topology_request
  end

  test "form_describe_topology_request() returns error when called with something other than string" do
    params = 123

    assert {:error, {:user, message}} = RequestFormatter.form_describe_topology_request(params)
    assert message == "Parameter pipeline_id must be a string."
  end

  # Validate YAML

  test "form_validate_request() returns {:ok, request} when called with map with all params" do
    params = %{"pipeline_id" => "123", "yaml_definition" => "definition"}

    assert {:ok, validate_request} = RequestFormatter.form_validate_request(params)
    assert %ValidateYamlRequest{} = validate_request
  end

  test "form_validate_request() returns error when called with map with misssing params" do
    params = %{"pipeline_id" => "123", "yaml_definition" => "definition"}

    [{"yaml_definition", :required}, {"pipeline_id", :optional}]
    |> Enum.map(fn {field_name, mode} -> test_post_param_is_required(params, field_name, mode) end)
  end

  defp test_post_param_is_required(params, field_name, mode) do
    params = Map.delete(params, field_name)

    case mode do
      :required ->
        assert {:error, {:user, message}} = RequestFormatter.form_validate_request(params)
        assert message == "Missing required post parameter #{field_name}."

      :optional ->
        assert {:ok, validate_request} = RequestFormatter.form_validate_request(params)
        assert %ValidateYamlRequest{} = validate_request
    end
  end

  test "form_validate_request() returns internal error when it is not called with map as a param" do
    params = "123"

    assert {:error, {:internal, message}} = RequestFormatter.form_validate_request(params)
    assert message == "Internal error"
  end
end
