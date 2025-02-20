defmodule Front.Clients.PipelineTest do
  use FrontWeb.ConnCase

  alias Front.Clients.Pipeline

  alias InternalApi.Plumber.{
    DescribeManyRequest,
    DescribeRequest,
    DescribeTopologyRequest,
    TerminateRequest
  }

  alias Support.Factories

  describe ".describe" do
    test "returns DescribeResponse for DescribeRequest" do
      request = DescribeRequest.new()
      response = Factories.Pipeline.describe_response()

      GrpcMock.stub(PipelineMock, :describe, response)
      assert {:ok, response} == Pipeline.describe(request)
    end
  end

  describe "describe_many" do
    test "returns DescribeManyResponse for DescribeManyRequest" do
      request = DescribeManyRequest.new()
      response = Factories.Pipeline.describe_many_response()

      GrpcMock.stub(PipelineMock, :describe_many, response)
      assert {:ok, response} == Pipeline.describe_many(request)
    end
  end

  describe "describe_topology" do
    test "returns DescribeTopologyResponse for DescribeTopologyRequest" do
      request = DescribeTopologyRequest.new()

      response = Factories.Pipeline.describe_topology_response()
      GrpcMock.stub(PipelineMock, :describe_topology, response)

      assert {:ok, response} == Pipeline.describe_topology(request)
    end
  end

  describe "terminate" do
    test "returns TerminateResponse for TerminateRequest" do
      request = TerminateRequest.new()

      response = Factories.Pipeline.terminate_response()
      GrpcMock.stub(PipelineMock, :terminate, response)

      assert {:ok, response} == Pipeline.terminate(request)
    end
  end
end
