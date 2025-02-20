defmodule Gofer.PlumberClient.RequestFormatter.Test do
  use ExUnit.Case

  alias Gofer.PlumberClient.RequestFormatter
  alias InternalApi.Plumber.{ScheduleExtensionRequest, DescribeRequest, EnvVariable}

  test "creates valid ScheduleExtension proto message when given valid params" do
    ppl_id = UUID.uuid4()
    file_path = "./pro.yml"
    request_token = UUID.uuid4()
    prev_ids = [UUID.uuid4(), UUID.uuid4()]

    params = %{
      ppl_id: ppl_id,
      file_path: file_path,
      request_token: request_token,
      prev_ppl_artefact_ids: prev_ids,
      env_variables: [%{"name" => "A", "value" => "a"}, %{"name" => "B", "value" => "b"}],
      secret_names: ["DTabcd1234ef56"],
      promoted_by: "123",
      auto_promoted: true
    }

    assert {:ok, request} = RequestFormatter.form_schedule_extension_request(params)

    assert %ScheduleExtensionRequest{
             ppl_id: ^ppl_id,
             file_path: ^file_path,
             request_token: ^request_token,
             prev_ppl_artefact_ids: ^prev_ids,
             promoted_by: "123",
             auto_promoted: true
           } = request

    assert is_list(request.env_variables)
    assert %EnvVariable{name: "A", value: "a"} == Enum.at(request.env_variables, 0)
    assert %EnvVariable{name: "B", value: "b"} == Enum.at(request.env_variables, 1)
    assert ["DTabcd1234ef56"] == request.secret_names
  end

  test "creates valid DescribeRequest proto message when given valid params" do
    ppl_id = UUID.uuid4()

    assert {:ok, request} = RequestFormatter.form_describe_request(ppl_id)
    assert %DescribeRequest{ppl_id: ^ppl_id, detailed: false} = request
  end
end
