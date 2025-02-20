defmodule Front.Widgets.Duration do
  require Logger

  defp timestamp(_, nil), do: nil

  defp timestamp(:beginning, date) do
    case date |> Timex.to_datetime() do
      {:error, _} -> nil
      s -> s |> to_google_timestamp
    end
  end

  defp timestamp(:end, date) do
    case date |> Timex.to_datetime() do
      {:error, _} -> nil
      s -> s |> Timex.end_of_day() |> to_google_timestamp
    end
  end

  defp to_google_timestamp(date) do
    case Timex.to_unix(date) do
      {:error, _} -> nil
      s -> Google.Protobuf.Timestamp.new(seconds: s)
    end
  end

  def data(project_id, branch_name, yml_file_path, _org_id, _user_id, from, to, tracing_headers) do
    alias Front.Models.Pipeline

    params = [
      project_id: project_id,
      branch_name: branch_name,
      yml_file_path: yml_file_path,
      created_after: timestamp(:beginning, from),
      created_before: timestamp(:end, to)
    ]

    options = [pagination: :auto]
    pipelines = Pipeline.list(params, options, tracing_headers)
    max = pipelines |> map |> max
    avg = pipelines |> map |> avg

    labels = max |> Enum.map(fn {k, _} -> k end)
    avg = avg |> Enum.map(fn {_, v} -> v end)
    max = max |> Enum.map(fn {_, v} -> v end)

    %{date: labels, values: [max, avg], names: ["Max", "Avg"]}
  end

  def map(pipelines) do
    pipelines
    |> Enum.map(fn p -> {p.timeline.done_at, p.timeline.duration} end)
    |> Enum.group_by(
      fn {date, _} -> date |> Timex.from_unix() |> Timex.to_date() |> Timex.to_unix() end,
      fn {_, duration} -> duration end
    )
  end

  defp max(data) do
    data
    |> Enum.map(fn {date, values} -> {date, values |> Enum.max()} end)
    |> Enum.into(%{})
  end

  defp avg(data) do
    data
    |> Enum.map(fn {date, values} -> {date, Enum.sum(values) / Enum.count(values)} end)
    |> Enum.into(%{})
  end
end
