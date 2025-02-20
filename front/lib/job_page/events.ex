defmodule JobPage.Events do
  def fetch_events(job_id, starting_event) do
    Watchman.benchmark({"fetch_events.duration", ["#{job_id}"]}, fn ->
      case JobPage.Api.Loghub.fetch(job_id, starting_event) do
        {:ok, events} ->
          recoded_events = events.events |> recode_events()
          {:ok, %{events | events: recoded_events} |> assign_next()}

        {:error, message} ->
          {:error, message}
      end
    end)
  end

  def raw_events(job_id, starting_event, take) do
    Watchman.benchmark({"raw_events.duration", ["#{job_id}"]}, fn ->
      case JobPage.Api.Loghub.fetch(job_id, starting_event) do
        {:ok, events} ->
          events = limit_take(events, take)

          Enum.join(['{ "events": [', Enum.join(recode_events(events.events), ","), "] }"], "")

        {:error, message} ->
          %{message: message}
      end
    end)
  end

  def raw_logs(job_id, starting_event, take) do
    Watchman.benchmark({"raw_logs.duration", ["#{job_id}"]}, fn ->
      case JobPage.Api.Loghub.fetch(job_id, starting_event) do
        {:ok, events} ->
          events = limit_take(events, take)

          events.events
          |> decode_events()
          |> filter_commands()
          |> map_commands()
          |> Enum.join("")

        {:error, message} ->
          message
      end
    end)
  end

  defp recode_events(events) do
    events
    |> decode_events()
    |> Enum.map(fn event ->
      Jason.encode!(event)
    end)
  end

  defp decode_events(events) do
    {_, events} =
      events
      |> Enum.reduce({0, []}, fn event, {last_timestamp, acc} ->
        Jason.decode(event)
        |> case do
          {:ok, event} ->
            {event["timestamp"], [event | acc]}

          {:error, %Jason.DecodeError{data: data, position: position}} ->
            # Add red color to the output, and print the error message
            event = %{
              "timestamp" => last_timestamp,
              "event" => "cmd_output",
              "output" =>
                "\u001b[31mDECODING LOG FAILED[at position: #{position}]: #{data}\u001b[0m\r\n"
            }

            {last_timestamp, [event | acc]}
        end
      end)

    events
    |> Enum.reverse()
  end

  defp filter_commands(events) do
    events
    |> Enum.filter(fn event ->
      event["event"] in ["cmd_started", "cmd_output"]
    end)
  end

  defp map_commands(events) do
    events
    |> Enum.map(fn event ->
      case Map.fetch!(event, "event") do
        "cmd_started" -> "#{Map.fetch!(event, "directive")}\n"
        "cmd_output" -> Map.fetch!(event, "output")
      end
    end)
  end

  defp assign_next(collection) do
    next =
      if collection.final do
        "null"
      else
        collection.last_event
      end

    %{
      events: collection.events,
      next: next
    }
  end

  defp limit_take(collection, 0) do
    %{
      events: collection.events,
      next: next(collection.final, collection.last_event, 0)
    }
  end

  defp limit_take(collection, take) do
    rest = Enum.max([0, Enum.count(collection.events) - take])

    %{
      events: Enum.take(collection.events, take),
      next: next(collection.final, collection.last_event, rest)
    }
  end

  defp next(true, _, 0), do: nil
  defp next(_, last_event, rest), do: last_event - rest
end
