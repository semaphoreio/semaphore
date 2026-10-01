defmodule InternalClients.Schedulers.ResponseFormatterTest do
  use ExUnit.Case, async: true

  alias InternalClients.Schedulers.ResponseFormatter
  alias InternalApi.PeriodicScheduler, as: API
  alias InternalApi.Status

  describe "process_response/1 with DescribeResponse" do
    test "maps parameter regex_pattern and validate_input_format" do
      param = %API.Periodic.Parameter{
        name: "VERSION",
        description: "Release version",
        required: true,
        default_value: "1.0.0",
        options: [],
        regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$",
        validate_input_format: true
      }

      periodic = %API.Periodic{
        id: "task-1",
        name: "deploy",
        description: "",
        project_id: "p1",
        recurring: false,
        reference: "refs/heads/master",
        pipeline_file: "deploy.yml",
        at: "",
        parameters: [param]
      }

      response = %API.DescribeResponse{
        status: %Status{code: :OK},
        periodic: periodic
      }

      assert {:ok, task} = ResponseFormatter.process_response({:ok, response})

      assert [parameter] = task.spec.parameters

      assert parameter == %{
               name: "VERSION",
               description: "Release version",
               required: true,
               default_value: "1.0.0",
               options: [],
               regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$",
               validate_input_format: true
             }
    end

    test "defaults regex_pattern to empty string and validate_input_format to false" do
      param = %API.Periodic.Parameter{
        name: "PARAM",
        required: false,
        regex_pattern: "",
        validate_input_format: false
      }

      periodic = %API.Periodic{
        id: "task-2",
        name: "deploy",
        description: "",
        project_id: "p1",
        recurring: false,
        reference: "refs/heads/master",
        pipeline_file: "deploy.yml",
        at: "",
        parameters: [param]
      }

      response = %API.DescribeResponse{
        status: %Status{code: :OK},
        periodic: periodic
      }

      assert {:ok, task} = ResponseFormatter.process_response({:ok, response})

      assert [parameter] = task.spec.parameters
      assert parameter.regex_pattern == ""
      assert parameter.validate_input_format == false
    end
  end
end
