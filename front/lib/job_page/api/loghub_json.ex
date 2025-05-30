defmodule JobPage.Api.LoghubJSON do
  defstruct [:final, :events, :first_event, :last_event]
  require Logger

  def fetch(_job_id, starting_line) do
    {:ok, str} = File.read("test/support/raw_logs.json")
    events = Jason.decode!(str) |> Map.fetch!("events") |> Enum.slice(starting_line..-1)

    last_event = Enum.count(events) + starting_line

    resp = %__MODULE__{
      final: true,
      events: events |> Enum.map(fn v -> Jason.encode!(v) end),
      first_event: starting_line,
      last_event: last_event
    }

    Logger.info(inspect(resp))
    {:ok, resp}
  end
end
