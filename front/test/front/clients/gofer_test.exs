defmodule Front.Clients.GoferTest do
  use FrontWeb.ConnCase

  alias Front.Clients.Gofer
  alias InternalApi.Gofer.{DescribeManyRequest, DescribeRequest, TriggerRequest}
  alias Support.Factories

  describe ".describe" do
    test "returns DescribeResponse for DescribeRequest" do
      request = DescribeRequest.new(switch_id: "90f128a7-bf6f-4502-be4a-c18b1e5074a3")
      response = Factories.Gofer.describe_response()

      GrpcMock.stub(GoferMock, :describe, response)

      assert {:ok, response} == Gofer.describe(request)
    end
  end

  describe ".describe_many" do
    test "returns DescribeManyResponse for DescribeManyRequest" do
      request =
        DescribeManyRequest.new(
          switch_ids: [
            "00755b80-5e54-4652-bac3-e0ef6e9451f0",
            "c8818b52-eed4-41d0-9a13-d8142ff778bc"
          ],
          events_per_target: 10
        )

      response = Factories.Gofer.describe_many_response()
      GrpcMock.stub(GoferMock, :describe_many, response)

      assert {:ok, response} == Gofer.describe_many(request)
    end
  end

  describe ".trigger" do
    test "returns TriggerResponse for TriggerRequest" do
      request =
        TriggerRequest.new(
          switch_id: "d9633895-563e-4c6e-9891-3610d6114980",
          target_name: "Deploy to staging",
          triggered_by: "037a1d3b-f9ec-4e75-ba97-da251b7f285e",
          override: true,
          request_token: "34388657-d615-4221-bf88-4c87458828f8",
          env_variables: []
        )

      response = Factories.Gofer.succeeded_trigger_response()
      GrpcMock.stub(GoferMock, :trigger, response)

      assert {:ok, response} == Gofer.trigger(request)
    end
  end
end
