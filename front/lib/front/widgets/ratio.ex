defmodule Front.Widgets.Ratio do
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
    ratio = pipelines |> map |> ratio

    labels = ratio |> Enum.map(fn {k, _} -> k end)
    ratio = ratio |> Enum.map(fn {_, v} -> v end)

    %{date: labels, values: [ratio], names: ["Success Ratio"]}
  end

  def map(pipelines) do
    pipelines
    |> Enum.map(fn p -> {p.timeline.done_at, p.result} end)
    |> Enum.group_by(
      fn {date, _} -> date |> Timex.from_unix() |> Timex.to_date() |> Timex.to_unix() end,
      fn {_, result} -> result end
    )
  end

  defp ratio(data) do
    data
    |> Enum.map(fn {date, ratios} ->
      all = ratios |> Enum.count()
      success = ratios |> Enum.count(fn x -> x == :PASSED end)
      ratio = success / all
      {date, ratio}
    end)
    |> Enum.into(%{})
  end
end
