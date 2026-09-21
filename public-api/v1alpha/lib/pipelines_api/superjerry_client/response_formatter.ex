defmodule PipelinesAPI.SuperjerryClient.ResponseFormatter do
  @moduledoc "Reshapes Superjerry protobuf responses into JSON-friendly maps for the REST layer."

  alias PipelinesAPI.Util.ToTuple

  # total_count and disruption_timestamps on Flaky are intentionally NOT exposed — chosen field subset per design.
  @flaky_fields ~w(test_id test_name test_group test_runner test_file test_suite
                   pass_rate labels disruptions_count latest_disruption_hash
                   latest_disruption_run_id resolved scheduled ticket_url age)a
  @ts_fields ~w(latest_disruption_at first_disruption_at)a

  # ---- list_flaky_tests ----

  @spec process_list_flaky_tests_response({:ok, map()} | {:error, any()}, map()) ::
          {:ok, Scrivener.Page.t()} | {:error, any()}
  def process_list_flaky_tests_response({:ok, resp}, params) when is_map(resp) do
    entries = (resp.flaky_tests || []) |> Enum.reject(&is_nil/1) |> Enum.map(&flaky_to_map/1)
    {:ok, to_page(entries, resp, params, 20)}
  end

  def process_list_flaky_tests_response(error, _params), do: error

  defp flaky_to_map(flaky) do
    base = Map.take(flaky, @flaky_fields)

    ts =
      @ts_fields
      |> Enum.into(%{}, fn k -> {k, ts_to_string(Map.get(flaky, k))} end)

    base
    |> Map.merge(ts)
    |> Map.put(:disruption_history, history_to_list(Map.get(flaky, :disruption_history) || []))
  end

  # ---- flaky_test_details ----

  @spec process_flaky_test_details_response({:ok, map()} | {:error, any()}) ::
          {:ok, map()} | {:error, any()}
  def process_flaky_test_details_response({:ok, %{detail: detail}}) when not is_nil(detail) do
    contexts =
      detail.contexts
      |> Enum.with_index()
      |> Enum.map(fn {ctx, i} ->
        %{
          context: ctx,
          pass_rate: at(detail.pass_rates, i),
          p95_duration: at(detail.p95_durations, i),
          impact: at(detail.impacts, i),
          total_count: at(detail.total_counts, i),
          disruptions_count: at(detail.disruptions_count, i),
          hash: at(detail.hashes, i),
          disruption_timestamp: ts_to_string(at(detail.disruption_timestamps, i))
        }
      end)

    {:ok,
     %{
       id: detail.id,
       name: detail.name,
       group: Map.get(detail, :group),
       runner: Map.get(detail, :runner),
       file: Map.get(detail, :file),
       labels: Map.get(detail, :labels) || [],
       available_contexts: detail.available_contexts,
       selected_context: detail.selected_context,
       contexts: contexts
     }}
  end

  # proto3: detail nil means the server found no record — treat as 404.
  def process_flaky_test_details_response({:ok, _}), do: ToTuple.not_found_error("Not found")
  def process_flaky_test_details_response(error), do: error

  # ---- flaky_test_disruptions ----

  @spec process_flaky_test_disruptions_response({:ok, map()} | {:error, any()}, map()) ::
          {:ok, Scrivener.Page.t()} | {:error, any()}
  def process_flaky_test_disruptions_response({:ok, resp}, params) when is_map(resp) do
    entries =
      (resp.disruptions || [])
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn d ->
        %{
          context: d.context,
          hash: d.hash,
          run_id: d.run_id,
          timestamp: ts_to_string(d.timestamp)
        }
      end)

    {:ok, to_page(entries, resp, params, 10)}
  end

  def process_flaky_test_disruptions_response(error, _params), do: error

  # ---- histories ----

  @spec process_list_flaky_history_response({:ok, map()} | {:error, any()}) ::
          {:ok, list()} | {:error, any()}
  def process_list_flaky_history_response(resp), do: history_response(resp)

  @spec process_list_disruption_history_response({:ok, map()} | {:error, any()}) ::
          {:ok, list()} | {:error, any()}
  def process_list_disruption_history_response(resp), do: history_response(resp)

  defp history_response({:ok, resp}) when is_map(resp),
    do: {:ok, history_to_list(resp.disruptions || [])}

  defp history_response(error), do: error

  defp history_to_list(records) do
    records
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn r -> %{day: ts_to_string(Map.get(r, :day)), count: Map.get(r, :count)} end)
  end

  # ---- helpers ----

  defp to_page(entries, resp, params, page_size_default) do
    struct(Scrivener.Page, %{
      entries: entries,
      page_number: page(params),
      page_size: page_size(params, page_size_default),
      total_entries: Map.get(resp, :total_rows, length(entries)),
      total_pages: Map.get(resp, :total_pages, 1)
    })
  end

  defp at(nil, _i), do: nil
  defp at(list, i), do: Enum.at(list, i)

  defp ts_to_string(nil), do: nil

  defp ts_to_string(%{seconds: s}) when is_integer(s) and s > 0 do
    case DateTime.from_unix(s) do
      {:ok, dt} -> DateTime.to_string(dt)
      _ -> nil
    end
  end

  defp ts_to_string(_), do: nil

  defp page(params), do: int_or(params["page"], 1)
  defp page_size(params, default), do: int_or(params["page_size"], default)

  defp int_or(v, d) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} when n > 0 -> n
      _ -> d
    end
  end

  defp int_or(_, d), do: d
end
