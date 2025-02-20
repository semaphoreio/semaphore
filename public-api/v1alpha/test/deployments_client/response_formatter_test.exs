defmodule PipelinesAPI.DeploymentTargetsClient.ResponseFormatter.Test do
  use ExUnit.Case

  alias PipelinesAPI.DeploymentTargetsClient.ResponseFormatter

  alias InternalApi.Gofer.DeploymentTargets.{
    ListResponse,
    CreateResponse,
    DeleteResponse,
    DescribeResponse,
    HistoryResponse
  }

  alias Util.Proto

  test "process_list_response() returns {:ok, msg} when given valid params" do
    targetsMap = [
      %{
        :id => "id1",
        :name => "name1",
        :description => "description1",
        :url => "http://url1.com",
        :updated_at => %{nanos: 123_456_789, seconds: 1_234_567_890}
      }
    ]

    response = make_deployments(targetsMap)

    assert {:ok, deployments} = ResponseFormatter.process_list_response(response)

    assert length(deployments) == 1

    expected = [
      Map.merge(
        Proto.deep_new!(InternalApi.Gofer.DeploymentTargets.DeploymentTarget, %{})
        |> Proto.to_map!(),
        %{
          description: "description1",
          id: "id1",
          name: "name1",
          updated_at: "2009-02-13T23:31:30.123456Z",
          url: "http://url1.com",
          state: "SYNCING",
          active: true
        }
      )
      |> Map.drop([:secret_name, :cordoned])
    ]

    assert ^expected = deployments
  end

  test "process_create_response() returns {:ok, msg} when given valid params" do
    assert {:ok, response} =
             %{
               target: %{
                 :id => "id1",
                 :name => "name1",
                 :description => "description1",
                 :url => "http://url1.com",
                 :state => 2
               }
             }
             |> Util.Proto.deep_new(CreateResponse)

    assert {:ok, targetMap} = ResponseFormatter.process_create_response({:ok, response})

    assert targetMap.id == response.target.id
    assert targetMap.state == "UNUSABLE"
  end

  test "process_delete_response() returns {:ok, msg} when given valid params" do
    assert {:ok, response} =
             %{target_id: "id1"}
             |> Util.Proto.deep_new(DeleteResponse)

    assert {:ok, targetMap} = ResponseFormatter.process_delete_response({:ok, response})
    assert targetMap.target_id == response.target_id
  end

  test "process_describe_response() returns {:ok, msg} when given valid params" do
    assert {:ok, response} =
             %{
               target: %{
                 id: "id1",
                 name: "name1",
                 description: "description1",
                 url: "http://url1.com"
               }
             }
             |> Util.Proto.deep_new(DescribeResponse)

    assert {:ok, processed} = ResponseFormatter.process_describe_response({:ok, response})
    assert processed.id == response.target.id
  end

  test "process_history_response() returns {:ok, msg} when given valid params" do
    assert {:ok, response} =
             %{
               deployments: [
                 %{
                   id: "id1",
                   target_id: "targ1",
                   prev_pipeline_id: "prevPplId",
                   pipeline_id: "pplId",
                   env_vars: [%{name: "VAR", value: "VALUE"}]
                 }
               ],
               cursor_before: 0,
               cursor_after: 20
             }
             |> Util.Proto.deep_new(HistoryResponse)

    assert {:ok, responseMap} = ResponseFormatter.process_history_response({:ok, response})
    assert length(responseMap.deployments) == 1

    expected = %{
      id: "id1",
      target_id: "targ1",
      prev_pipeline_id: "prevPplId",
      pipeline_id: "pplId",
      env_vars: [%{name: "VAR", value: "VALUE"}],
      state: "PENDING",
      state_message: "",
      switch_id: "",
      target_name: "",
      triggered_at: nil,
      triggered_by: ""
    }

    deployment = responseMap.deployments |> Enum.at(0)
    fields = ~w(id target_id prev_pipeline_id pipeline_id state)a
    assert Map.equal?(expected |> Map.take(fields), deployment |> Map.take(fields))
    assert Map.equal?(expected.env_vars |> Enum.at(0), deployment.env_vars |> Enum.at(0))
  end

  defp make_deployments(targetsMap) do
    Proto.deep_new(ListResponse, %{targets: targetsMap})
  end
end
