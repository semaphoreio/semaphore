defmodule Support.Factories.Gofer do
  alias InternalApi.Gofer.{
    DescribeManyResponse,
    DescribeResponse,
    ResponseStatus,
    SwitchDetails,
    TargetDescription,
    TriggerEvent
  }

  alias Google.Protobuf.Timestamp
  alias InternalApi.Gofer.ResponseStatus.ResponseCode

  def describe_response do
    DescribeResponse.new(
      response_status: ResponseStatus.new(code: ResponseCode.value(:OK)),
      ppl_id: "e5a94564-e26f-4e08-94b3-e51d959e0105",
      switch_id: "58c9aa4d-ad20-4249-8088-88ae1a526fa8",
      targets: [TargetDescription.new(name: "Deploy to Prod")]
    )
  end

  def bad_describe_response do
    DescribeResponse.new(
      response_status: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM))
    )
  end

  def describe_response(nil) do
    DescribeResponse.new(
      response_status: ResponseStatus.new(code: ResponseCode.value(:NOT_FOUND))
    )
  end

  def describe_response(switch) do
    targets =
      Enum.map(switch.targets, fn target ->
        events =
          Enum.map(target.events, fn event ->
            TriggerEvent.new(
              processing_result: TriggerEvent.ProcessingResult.value(event.result),
              triggered_by: "a8114608-be8a-465a-b9cd-81970fb802c7",
              triggered_at: Timestamp.new(seconds: 999),
              scheduled_pipeline_id: event.ppl_id,
              processed: event.processed
            )
          end)

        TargetDescription.new(
          name: target.name,
          trigger_events: events
        )
      end)

    DescribeResponse.new(
      response_status: ResponseStatus.new(code: ResponseCode.value(:OK)),
      ppl_id: switch.ppl_id,
      switch_id: switch.id,
      targets: targets
    )
  end

  def describe_many_response do
    DescribeManyResponse.new(
      response_status: ResponseStatus.new(code: ResponseCode.value(:OK)),
      switches: [SwitchDetails.new(), SwitchDetails.new()]
    )
  end

  def succeeded_trigger_response do
    InternalApi.Gofer.TriggerResponse.new(
      response_status:
        InternalApi.Gofer.ResponseStatus.new(
          code: InternalApi.Gofer.ResponseStatus.ResponseCode.value(:OK)
        )
    )
  end

  def failed_trigger_response do
    InternalApi.Gofer.TriggerResponse.new(
      response_status:
        InternalApi.Gofer.ResponseStatus.new(
          code: InternalApi.Gofer.ResponseStatus.ResponseCode.value(:BAD_PARAM),
          message: "Promotion request is invalid."
        )
    )
  end

  def refused_trigger_response(message \\ "Promotion request was refused.") do
    InternalApi.Gofer.TriggerResponse.new(
      response_status:
        InternalApi.Gofer.ResponseStatus.new(
          code: InternalApi.Gofer.ResponseStatus.ResponseCode.value(:REFUSED),
          message: message
        )
    )
  end
end
