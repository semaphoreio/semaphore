defmodule Front.Audit.EventsDecorator.PreloaderTest do
  use ExUnit.Case, async: false

  alias Front.Audit.EventsDecorator
  alias InternalApi.Audit.Event.{Medium, Operation, Resource}
  alias InternalApi.Plumber.DescribeManyResponse
  alias InternalApi.Plumber.ResponseStatus
  alias InternalApi.Plumber.ResponseStatus.ResponseCode

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    :ok
  end

  defp event(opts) do
    %{
      resource: Resource.value(:Pipeline),
      operation: Operation.value(:Added),
      medium: Medium.value(:API),
      user_id: UUID.uuid4(),
      username: "shiroyasha",
      ip_address: "189.0.12.2",
      operation_id: UUID.uuid4(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
      resource_id: UUID.uuid4(),
      resource_name: "my-pipeline",
      description: "Added a pipeline",
      metadata: Poison.encode!(%{})
    }
    |> Map.merge(Map.new(opts))
    |> InternalApi.Audit.Event.new()
  end

  defp stub_describe_many_bad_param do
    GrpcMock.stub(PipelineMock, :describe_many, fn _req, _stream ->
      DescribeManyResponse.new(
        response_status:
          ResponseStatus.new(
            code: ResponseCode.value(:BAD_PARAM),
            message: "Pipeline with id: 0e0e0e0e-0e0e-4e0e-8e0e-0e0e0e0e0e0e not found"
          )
      )
    end)
  end

  test "renders events when plumber rejects the whole DescribeMany batch" do
    stub_describe_many_bad_param()

    events = [event(metadata: Poison.encode!(%{"pipeline_id" => UUID.uuid4()}))]

    assert [decorated] = EventsDecorator.decorate(events)
    assert decorated.has_pipeline == false
    assert decorated.pipeline == nil
  end

  test "does not send malformed pipeline ids to plumber" do
    GrpcMock.stub(PipelineMock, :describe_many, fn req, _stream ->
      assert req.ppl_ids == []

      DescribeManyResponse.new(
        response_status: ResponseStatus.new(code: ResponseCode.value(:OK)),
        pipelines: []
      )
    end)

    events = [event(metadata: Poison.encode!(%{"pipeline_id" => ""}))]

    assert [decorated] = EventsDecorator.decorate(events)
    assert decorated.has_pipeline == false
  end

  test "decorates a Group resource event" do
    events = [
      event(
        resource: Resource.value(:Group),
        operation: Operation.value(:Added),
        resource_name: "backend-team"
      )
    ]

    assert [decorated] = EventsDecorator.decorate(events)
    assert decorated.resource == :Group
  end
end
