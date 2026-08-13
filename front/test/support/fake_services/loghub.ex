defmodule Support.FakeServices.Loghub do
  use GRPC.Server, service: InternalApi.Loghub.Loghub.Service
  alias InternalApi.Loghub.GetLogEventsResponse

  def get_log_events(%{job_id: "43dfb721-42e3-48d5-871a-d0c2231435d9"}, _stream) do
    events =
      "test/support/loghub/broken_events"
      |> File.stream!()
      |> Enum.map(&String.trim/1)
      |> Enum.to_list()

    GetLogEventsResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      events: events,
      final: true
    )
  end

  def get_log_events(%{job_id: "9e0a1b2c-3d4e-4f5a-8b6c-7d8e9f0a1b2c"}, _stream) do
    events = [
      ~s({"event":"cmd_output","timestamp":1739285892,"output":"log-of-the-original-job\\n"})
    ]

    GetLogEventsResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      events: events,
      final: true
    )
  end

  def get_log_events(req, _stream) do
    events =
      File.read!("test/support/loghub/events")
      |> Poison.decode!()
      |> Map.get("events")
      |> Enum.drop(req.starting_line)
      |> Enum.map(fn event -> Poison.encode!(event) end)

    GetLogEventsResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      events: events,
      final: true
    )
  end
end
