defmodule Gofer.Grpc.ResponseFormatter.Test do
  use ExUnit.Case

  alias Gofer.Grpc.ResponseFormatter
  alias InternalApi.Gofer.ResponseStatus.ResponseCode

  alias InternalApi.Gofer.{
    ResponseStatus,
    CreateResponse,
    PipelineDoneResponse,
    DescribeResponse,
    TargetDescription,
    TriggerEvent,
    ListTriggerEventsResponse,
    TriggerResponse,
    EnvVariable,
    ParamEnvVar,
    AutoTriggerCond
  }

  alias Google.Protobuf.Timestamp
  alias Util.Proto

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    {:ok, %{}}
  end

  # Create

  test ":ok create action response is formed correctly" do
    id = UUID.uuid4()
    raw_resp = {:ok, id}

    assert response = ResponseFormatter.form_response(raw_resp, :create)
    assert %CreateResponse{switch_id: resp_id, response_status: status} = response
    assert id == resp_id
    assert %ResponseStatus{code: code(:OK), message: ""} == status
  end

  test ":error create action response is formed correctly" do
    error_msg = "Detailed error message"
    raw_resp = {:error, error_msg}
    assert response = ResponseFormatter.form_response(raw_resp, :create)
    assert %CreateResponse{switch_id: resp_id, response_status: status} = response
    assert resp_id == ""
    assert %ResponseStatus{code: code(:BAD_PARAM), message: error_msg} == status
  end

  # PipelineDone

  test ":ok pipeline_done action response is formed correctly" do
    ok_message = "Pipeline result recorded correctly"
    raw_resp = {:ok, {:OK, ok_message}}

    assert response = ResponseFormatter.form_response(raw_resp, :pipeline_done)
    assert %PipelineDoneResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:OK), message: ok_message} == status
  end

  test ":RESULT_CHANGED pipeline_done action response is formed correctly" do
    ch_message = "Pipeline result changed"
    raw_resp = {:ok, {:RESULT_CHANGED, ch_message}}

    assert response = ResponseFormatter.form_response(raw_resp, :pipeline_done)
    assert %PipelineDoneResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:RESULT_CHANGED), message: ch_message} == status
  end

  test ":error pipeline_done action response is formed correctly" do
    error_msg = "Detailed error message"
    raw_resp = {:error, error_msg}
    assert response = ResponseFormatter.form_response(raw_resp, :pipeline_done)
    assert %PipelineDoneResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:BAD_PARAM), message: error_msg} == status
  end

  # Trigger

  test ":ok trigger action response is formed correctly" do
    ok_message = "Target trigger request recorded."
    raw_resp = {:ok, {:OK, ok_message}}

    assert response = ResponseFormatter.form_response(raw_resp, :trigger)
    assert %TriggerResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:OK), message: ok_message} == status
  end

  test ":NOT_FOUND trigger action response is formed correctly" do
    message = "Switch with id xyz not found."
    raw_resp = {:ok, {:NOT_FOUND, message}}

    assert response = ResponseFormatter.form_response(raw_resp, :trigger)
    assert %TriggerResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:NOT_FOUND), message: message} == status
  end

  test ":REFUSED trigger action response is formed correctly" do
    message = "Triggering target when pipeline is not passed requires override confirmation."
    raw_resp = {:ok, {:REFUSED, message}}

    assert response = ResponseFormatter.form_response(raw_resp, :trigger)
    assert %TriggerResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:REFUSED), message: message} == status
  end

  test ":error trigger action response is formed correctly" do
    error_msg = "Detailed error message"
    raw_resp = {:error, error_msg}
    assert response = ResponseFormatter.form_response(raw_resp, :trigger)
    assert %TriggerResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:BAD_PARAM), message: error_msg} == status
  end

  # ListTriggerEvents

  test "valid list result with triggers is formatted correctly" do
    assert response = ResponseFormatter.form_response(list_with_triggers(), :list_triggers)
    assert %ListTriggerEventsResponse{response_status: status} = response
    assert %ResponseStatus{code: ResponseCode.value(:OK), message: ""} == status
    assert response.page_number == 1
    assert response.page_size == 3
    assert response.total_entries == 5
    assert response.total_pages == 2
    assert trigger_events_correct(response.trigger_events)
  end

  test "valid list result without triggers is formatted correctly" do
    resp =
      {:ok,
       %{page_number: 1, page_size: 10, total_entries: 0, total_pages: 1, trigger_events: []}}

    assert response = ResponseFormatter.form_response(resp, :list_triggers)
    assert %ListTriggerEventsResponse{response_status: status} = response
    assert %ResponseStatus{code: ResponseCode.value(:OK), message: ""} == status
    assert response.page_number == 1
    assert response.page_size == 10
    assert response.total_entries == 0
    assert response.total_pages == 1
    assert response.trigger_events == []
  end

  test ":NOT_FOUND list action response is formed correctly" do
    message = "Switch with id xyz not found."
    action_result = {:ok, {:NOT_FOUND, message}}

    assert response = ResponseFormatter.form_response(action_result, :list_triggers)

    assert %ListTriggerEventsResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:NOT_FOUND), message: message} == status
  end

  test ":error list action response is formed correctly" do
    error_msg = "Detailed error message"
    raw_resp = {:error, error_msg}
    assert response = ResponseFormatter.form_response(raw_resp, :list_triggers)
    assert %ListTriggerEventsResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:BAD_PARAM), message: error_msg} == status
  end

  defp list_with_triggers() do
    {:ok,
     %{
       page_number: 1,
       page_size: 3,
       total_entries: 5,
       total_pages: 2,
       trigger_events: [
         # Passed trigger_event
         %{
           auto_triggered: true,
           error_response: "",
           override: false,
           processing_result: "passed",
           scheduled_at: DateTime.utc_now(),
           triggered_by: "Pipeline Done request",
           processed: true,
           scheduled_pipeline_id: UUID.uuid4(),
           triggered_at: DateTime.utc_now(),
           target_name: "prod"
         },
         # Not processed trigger_event
         %{
           auto_triggered: true,
           error_response: "",
           override: false,
           processed: false,
           processing_result: "",
           scheduled_at: nil,
           scheduled_pipeline_id: "",
           target_name: "staging",
           triggered_at: DateTime.utc_now(),
           triggered_by: "Pipeline Done request",
           env_variables: [%{"name" => "TEST", "value" => "1"}]
         },
         # Failed trigger_event
         %{
           auto_triggered: true,
           error_response: "Error",
           processed: true,
           target_name: "staging",
           processing_result: "failed",
           scheduled_at: DateTime.utc_now(),
           scheduled_pipeline_id: "",
           triggered_at: DateTime.utc_now(),
           triggered_by: "Pipeline Done request",
           override: false,
           env_variables: [%{"name" => "TEST", "value" => "1"}]
         }
       ]
     }}
  end

  # Describe

  test "valid description with triggers is formatted correctly" do
    assert response = ResponseFormatter.form_response(description_with_triggers(), :describe)
    assert %DescribeResponse{response_status: status} = response
    assert %ResponseStatus{code: ResponseCode.value(:OK), message: ""} == status
    assert response.pipeline_done == true
    assert response.pipeline_result == "passed"
    assert {:ok, _} = UUID.info(response.ppl_id)
    assert {:ok, _} = UUID.info(response.switch_id)
    assert targets_description_valid(response.targets, true)
    assert response.targets |> Enum.map(& &1.dt_description) |> Enum.all?(&is_nil/1)
  end

  defp targets_description_valid(targets, has_triggers?) when is_list(targets) do
    targets
    |> Enum.map(fn target ->
      assert %TargetDescription{} = target
      assert target.name in ["prod", "staging"]
      assert target.pipeline_path in ["./prod.yml", "./stg.yml"]

      if target.name == "staging" do
        assert target.auto_trigger_on ==
                 [
                   %AutoTriggerCond{
                     result: "passed",
                     result_reason: "",
                     branch: ["mast.", "xyz"],
                     labels: [],
                     label_patterns: []
                   },
                   %AutoTriggerCond{
                     result: "failed",
                     result_reason: "test",
                     branch: ["123"],
                     labels: [],
                     label_patterns: []
                   }
                 ]

        assert target.parameter_env_vars ==
                 [
                   %{name: "TEST", options: ["1", "2"], default_value: "3"}
                   |> Proto.deep_new!(ParamEnvVar)
                 ]
      else
        assert target.auto_trigger_on == []
        assert target.parameter_env_vars == []
      end

      case has_triggers? do
        true -> assert trigger_events_correct(target.trigger_events)
        false -> assert target.trigger_events == []
      end
    end)

    true
  end

  defp targets_description_valid(_, _), do: false

  defp trigger_events_correct(triggers) when is_list(triggers) do
    triggers
    |> Enum.map(fn trigger ->
      assert %TriggerEvent{} = trigger
      assert trigger.auto_triggered == true
      assert trigger.error_response in ["", "Error"]
      assert trigger.override == false
      assert trigger.processed in [true, false]
      assert trigger.processing_result in [0, 1]
      assert %Timestamp{} = trigger.triggered_at
      assert %Timestamp{} = trigger.scheduled_at
      assert is_binary(trigger.scheduled_pipeline_id)
      assert trigger.target_name in ["prod", "staging"]
      assert trigger.triggered_by == "Pipeline Done request"

      if trigger.target_name == "staging" do
        assert trigger.env_variables == [%EnvVariable{name: "TEST", value: "1"}]
      else
        assert trigger.env_variables == []
      end
    end)

    true
  end

  defp trigger_events_correct(_), do: false

  test "valid description with dt descriptions is formatted correctly" do
    assert response =
             ResponseFormatter.form_response(description_with_dt_descriptions(), :describe)

    assert %DescribeResponse{response_status: status} = response
    assert %ResponseStatus{code: ResponseCode.value(:OK), message: ""} == status
    assert response.pipeline_done == true
    assert response.pipeline_result == "passed"
    assert {:ok, _} = UUID.info(response.ppl_id)
    assert {:ok, _} = UUID.info(response.switch_id)
    assert targets_description_valid(response.targets, true)

    assert staging_target = Enum.find(response.targets, &(&1.name == "staging"))
    assert {:ok, _} = UUID.info(staging_target.dt_description.target_id)
    assert staging_target.dt_description.target_name == "staging"
    assert staging_target.dt_description.access.allowed

    assert staging_target.dt_description.access.reason ==
             InternalApi.Gofer.DeploymentTargetDescription.Access.Reason.value(:NO_REASON)

    assert staging_target.dt_description.access.message == "User can deploy"

    assert prod_target = Enum.find(response.targets, &(&1.name == "prod"))
    assert {:ok, _} = UUID.info(prod_target.dt_description.target_id)
    assert prod_target.dt_description.target_name == "production"
    refute prod_target.dt_description.access.allowed

    assert prod_target.dt_description.access.reason ==
             InternalApi.Gofer.DeploymentTargetDescription.Access.Reason.value(:BANNED_SUBJECT)

    assert prod_target.dt_description.access.message == "User cannot deploy"
  end

  defp description_with_dt_descriptions() do
    {:ok,
     %{
       pipeline_done: true,
       pipeline_result: "passed",
       ppl_id: UUID.uuid4(),
       switch_id: UUID.uuid4(),
       targets: [
         %{
           name: "prod",
           pipeline_path: "./prod.yml",
           trigger_events: [],
           parameter_env_vars: [],
           auto_trigger_on: [],
           dt_description: %{
             target_id: UUID.uuid4(),
             target_name: "production",
             access: %{
               allowed: false,
               reason: :BANNED_SUBJECT,
               message: "User cannot deploy"
             }
           }
         },
         %{
           name: "staging",
           pipeline_path: "./stg.yml",
           trigger_events: [],
           auto_trigger_on: [
             %{"result" => "passed", "branch" => ["mast.", "xyz"]},
             %{"result" => "failed", "result_reason" => "test", "branch" => ["123"]}
           ],
           parameter_env_vars: [
             %{
               name: "TEST",
               options: ["1", "2"],
               default_value: "3",
               required: false,
               description: ""
             }
           ],
           dt_description: %{
             target_id: UUID.uuid4(),
             target_name: "staging",
             access: %{allowed: true, reason: :NO_REASON, message: "User can deploy"}
           }
         }
       ]
     }}
  end

  test "valid description without triggers is formatted correctly" do
    assert response = ResponseFormatter.form_response(description_without_triggers(), :describe)
    assert %DescribeResponse{response_status: status} = response
    assert %ResponseStatus{code: ResponseCode.value(:OK), message: ""} == status
    assert response.pipeline_done == true
    assert response.pipeline_result == "passed"
    assert {:ok, _} = UUID.info(response.ppl_id)
    assert {:ok, _} = UUID.info(response.switch_id)
    assert targets_description_valid(response.targets, false)
    assert response.targets |> Enum.map(& &1.dt_description) |> Enum.all?(&is_nil/1)
  end

  test ":NOT_FOUND describe action response is formed correctly" do
    message = "Switch with id xyz not found."
    action_result = {:ok, {:NOT_FOUND, message}}

    assert response = ResponseFormatter.form_response(action_result, :describe)

    assert %DescribeResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:NOT_FOUND), message: message} == status
  end

  test ":error describe action response is formed correctly" do
    error_msg = "Detailed error message"
    raw_resp = {:error, error_msg}
    assert response = ResponseFormatter.form_response(raw_resp, :describe)
    assert %DescribeResponse{response_status: status} = response
    assert %ResponseStatus{code: code(:BAD_PARAM), message: error_msg} == status
  end

  defp description_with_triggers() do
    {:ok,
     %{
       pipeline_done: true,
       pipeline_result: "passed",
       ppl_id: UUID.uuid4(),
       switch_id: UUID.uuid4(),
       targets: [
         %{
           name: "prod",
           pipeline_path: "./prod.yml",
           parameter_env_vars: [],
           auto_trigger_on: [],
           trigger_events: [
             # Passed trigger_event
             %{
               auto_triggered: true,
               error_response: "",
               override: false,
               processing_result: "passed",
               scheduled_at: DateTime.utc_now(),
               triggered_by: "Pipeline Done request",
               processed: true,
               scheduled_pipeline_id: UUID.uuid4(),
               triggered_at: DateTime.utc_now(),
               target_name: "prod"
             }
           ]
         },
         %{
           name: "staging",
           pipeline_path: "./stg.yml",
           auto_trigger_on: [
             %{"result" => "passed", "branch" => ["mast.", "xyz"]},
             %{"result" => "failed", "result_reason" => "test", "branch" => ["123"]}
           ],
           parameter_env_vars: [
             %{
               name: "TEST",
               options: ["1", "2"],
               default_value: "3",
               required: false,
               description: ""
             }
           ],
           trigger_events: [
             # Not processed trigger_event
             %{
               auto_triggered: true,
               error_response: "",
               override: false,
               processed: false,
               processing_result: "",
               scheduled_at: nil,
               scheduled_pipeline_id: "",
               target_name: "staging",
               triggered_at: DateTime.utc_now(),
               triggered_by: "Pipeline Done request",
               env_variables: [%{"name" => "TEST", "value" => "1"}]
             },
             # Failed trigger_event
             %{
               auto_triggered: true,
               error_response: "Error",
               processed: true,
               target_name: "staging",
               processing_result: "failed",
               scheduled_at: DateTime.utc_now(),
               scheduled_pipeline_id: "",
               triggered_at: DateTime.utc_now(),
               triggered_by: "Pipeline Done request",
               override: false,
               env_variables: [%{"name" => "TEST", "value" => "1"}]
             }
           ]
         }
       ]
     }}
  end

  defp description_without_triggers() do
    {:ok,
     %{
       pipeline_done: true,
       pipeline_result: "passed",
       ppl_id: UUID.uuid4(),
       switch_id: UUID.uuid4(),
       targets: [
         %{
           name: "prod",
           pipeline_path: "./prod.yml",
           trigger_events: [],
           parameter_env_vars: [],
           auto_trigger_on: []
         },
         %{
           name: "staging",
           pipeline_path: "./stg.yml",
           trigger_events: [],
           auto_trigger_on: [
             %{"result" => "passed", "branch" => ["mast.", "xyz"]},
             %{"result" => "failed", "result_reason" => "test", "branch" => ["123"]}
           ],
           parameter_env_vars: [
             %{
               name: "TEST",
               options: ["1", "2"],
               default_value: "3",
               required: false,
               description: ""
             }
           ]
         }
       ]
     }}
  end

  defp code(value), do: value
end
