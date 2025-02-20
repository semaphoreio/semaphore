defmodule Gofer.Grpc.RequestParser.Test do
  use ExUnit.Case

  alias Gofer.Grpc.RequestParser

  alias InternalApi.Gofer.{
    CreateRequest,
    Target,
    PipelineDoneRequest,
    DescribeRequest,
    ListTriggerEventsRequest,
    TriggerRequest,
    ParamEnvVar,
    AutoTriggerCond
  }

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    target_1 =
      %{
        name: "staging",
        pipeline_path: "./staging.yml",
        deployment_target: "production",
        auto_trigger_on: [AutoTriggerCond.new(result: "passed", branch: ["mast.", "xyz"])]
      }
      |> Target.new()

    p_e_v = [
      ParamEnvVar.new(%{
        name: "Test",
        options: ["1", "2"],
        required: true,
        default_value: "7",
        description: "Lorem ipsum"
      })
    ]

    target_2 =
      %{name: "prod", pipeline_path: "./prod.yml", parameter_env_vars: p_e_v}
      |> Target.new()

    targets = [target_1, target_2]

    create_request =
      %{pipeline_id: UUID.uuid4(), targets: targets}
      |> CreateRequest.new()

    {:ok, %{create_request: create_request}}
  end

  test "valid CreateRequest is correctly parsed", ctx do
    assert {:ok, switch_def, targets_defs} = RequestParser.parse(ctx.create_request)

    assert %{"ppl_id" => ppl_id} = switch_def
    assert {:ok, _} = UUID.info(ppl_id)

    assert %{
             "name" => "staging",
             "pipeline_path" => "./staging.yml",
             "auto_trigger_on" => [
               %{
                 "result" => "passed",
                 "result_reason" => "",
                 "branch" => ["mast.", "xyz"],
                 "labels" => [],
                 "label_patterns" => []
               }
             ],
             "parameter_env_vars" => [],
             "auto_promote_when" => "",
             "deployment_target" => "production"
           } ==
             targets_defs |> Enum.at(0)

    assert %{
             "name" => "prod",
             "pipeline_path" => "./prod.yml",
             "auto_trigger_on" => [],
             "parameter_env_vars" => [
               %{
                 "name" => "Test",
                 "options" => ["1", "2"],
                 "required" => true,
                 "default_value" => "7",
                 "description" => "Lorem ipsum"
               }
             ],
             "auto_promote_when" => "",
             "deployment_target" => ""
           } ==
             targets_defs |> Enum.at(1)
  end

  test "valid PipelineDone request is correctly parsed" do
    id = UUID.uuid4()

    request =
      %{switch_id: id, result: "failed", result_reason: "test"} |> PipelineDoneRequest.new()

    assert {:ok, switch_id, result, result_reason} = RequestParser.parse(request)
    assert switch_id == id
    assert result == "failed"
    assert result_reason == "test"
  end

  test "valid TriggerRequest request is correctly parsed" do
    request =
      %{
        switch_id: UUID.uuid4(),
        target_name: "prod",
        triggered_by: "user1",
        override: false,
        request_token: UUID.uuid4()
      }
      |> TriggerRequest.new()

    assert {:ok, request_map} = RequestParser.parse(request)
    assert request_map.switch_id == request.switch_id
    assert request_map.target_name == request.target_name
    assert request_map.triggered_by == request.triggered_by
    assert request_map.override == request.override
    assert request_map.request_token == request.request_token
  end

  test "error is returned when TriggerRequest has empty string in triggered_by field" do
    request =
      %{
        switch_id: UUID.uuid4(),
        target_name: "prod",
        triggered_by: "",
        override: false,
        request_token: UUID.uuid4()
      }
      |> TriggerRequest.new()

    assert {:error, message} = RequestParser.parse(request)
    assert message == "Field triggered_by can not be empty."
  end

  test "valid ListTriggerEvents request is correctly parsed" do
    id = UUID.uuid4()

    request =
      %{switch_id: id, target_name: "prod", page: 1, page_size: 5}
      |> ListTriggerEventsRequest.new()

    assert {:ok, switch_id, target_name, page, page_size} = RequestParser.parse(request)
    assert switch_id == id
    assert target_name == "prod"
    assert page == 1
    assert page_size == 5
  end

  test "error is returned when ListTriggerEvents request has invalid page" do
    id = UUID.uuid4()

    request =
      %{switch_id: id, target_name: "prod", page: -5, page_size: 5}
      |> ListTriggerEventsRequest.new()

    assert {:error, message} = RequestParser.parse(request)
    assert message == "Page parameter must be integer greater or equal to 1."
  end

  test "error is returned when ListTriggerEvents request has invalid page_size" do
    id = UUID.uuid4()

    request =
      %{switch_id: id, target_name: "prod", page: 1, page_size: -10}
      |> ListTriggerEventsRequest.new()

    assert {:error, message} = RequestParser.parse(request)

    assert message ==
             "Page_size parameter must be integer greater or equal to 1 and lesser than 100."
  end

  test "valid Describe request in correctly parsed" do
    id = UUID.uuid4()
    user_id = UUID.uuid4()

    request =
      %{switch_id: id, events_per_target: 5, requester_id: user_id} |> DescribeRequest.new()

    assert {:ok, switch_id, targets_no, requester_id} = RequestParser.parse(request)
    assert switch_id == id
    assert targets_no == 5
    assert requester_id == user_id
  end

  test "error is returned when Describe request has invalid events_per_target" do
    id = UUID.uuid4()
    request = %{switch_id: id, events_per_target: -7, requester_id: ""} |> DescribeRequest.new()

    assert {:error, message} = RequestParser.parse(request)

    assert message ==
             """
             Invalid value of events_per_target parameter: -7.
             It has to be integer betwen 1 and 100.
             """
  end
end
