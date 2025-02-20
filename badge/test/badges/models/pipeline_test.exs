defmodule Badges.Models.PipelineTest do
  use ExUnit.Case

  alias Badges.Models.Pipeline

  describe ".find" do
    test "when the pipeline can't be found => it returns nil" do
      GrpcMock.stub(PipelineMock, :list_keyset, fn _, _ ->
        InternalApi.Plumber.ListKeysetResponse.new(pipelines: [])
      end)

      assert Pipeline.find(
               "12345678-1234-5678-0000-010101010101",
               "master",
               ".semaphore/semaphore.yml"
             ) == nil
    end

    test "when the pipeline can be found => it returns the project" do
      GrpcMock.stub(PipelineMock, :list_keyset, fn _, _ ->
        InternalApi.Plumber.ListKeysetResponse.new(pipelines: [Support.Factories.pipeline()])
      end)

      assert Pipeline.find(
               "12345678-1234-5678-0000-010101010101",
               "master",
               ".semaphore/semaphore.yml"
             ) == %Pipeline{
               id: "12345678-1234-5678-0000-010101010101",
               state: :DONE,
               result: :PASSED,
               reason: :TEST
             }
    end
  end
end
