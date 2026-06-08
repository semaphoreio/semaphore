defmodule PipelinesAPI.SuperjerryClient.RequestFormatter do
  @moduledoc "Builds Superjerry protobuf requests from HTTP params, incl. the @key:value filters string."

  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.Superjerry.{
    ListFlakyTestsRequest,
    FlakyTestDetailsRequest,
    FlakyTestDisruptionsRequest,
    ListFlakyHistoryRequest,
    ListDisruptionHistoryRequest,
    Pagination,
    Sort
  }

  @filter_map [
    {"branch", "@git.branch"},
    {"commit_sha", "@git.commit_sha"},
    {"test_name", "@test.name"},
    {"group", "@test.group"},
    {"file", "@test.file"},
    {"suite", "@test.suite"},
    {"runner", "@test.runner"},
    {"label", "@label"},
    {"resolved", "@is.resolved"},
    {"scheduled", "@is.scheduled"},
    {"age", "@metric.age"},
    {"pass_rate", "@metric.pass_rate"},
    {"disruptions", "@metric.disruptions"},
    {"date_from", "@date.from"},
    {"date_to", "@date.to"}
  ]

  @spec form_list_flaky_tests_request(map()) :: {:ok, ListFlakyTestsRequest.t()} | {:error, any()}
  def form_list_flaky_tests_request(params) when is_map(params) do
    %ListFlakyTestsRequest{
      org_id: params["org_id"] || "",
      project_id: params["project_id"] || "",
      filters: build_filters(params),
      pagination: %Pagination{page: page(params), page_size: page_size(params)},
      sort: %Sort{name: params["sort_field"] || "", dir: sort_dir(params)}
    }
    |> ToTuple.ok()
  end

  def form_list_flaky_tests_request(_), do: ToTuple.internal_error("Internal error")

  @spec form_flaky_test_details_request(map()) ::
          {:ok, FlakyTestDetailsRequest.t()} | {:error, any()}
  def form_flaky_test_details_request(params) when is_map(params) do
    %FlakyTestDetailsRequest{
      org_id: params["org_id"] || "",
      project_id: params["project_id"] || "",
      test_id: params["test_id"] || "",
      filters: build_filters(params)
    }
    |> ToTuple.ok()
  end

  def form_flaky_test_details_request(_), do: ToTuple.internal_error("Internal error")

  @spec form_flaky_test_disruptions_request(map()) ::
          {:ok, FlakyTestDisruptionsRequest.t()} | {:error, any()}
  def form_flaky_test_disruptions_request(params) when is_map(params) do
    %FlakyTestDisruptionsRequest{
      org_id: params["org_id"] || "",
      project_id: params["project_id"] || "",
      test_id: params["test_id"] || "",
      filters: build_filters(params),
      pagination: %Pagination{page: page(params), page_size: page_size(params, 10)}
    }
    |> ToTuple.ok()
  end

  def form_flaky_test_disruptions_request(_), do: ToTuple.internal_error("Internal error")

  @spec form_list_flaky_history_request(map()) ::
          {:ok, ListFlakyHistoryRequest.t()} | {:error, any()}
  def form_list_flaky_history_request(params) when is_map(params) do
    %ListFlakyHistoryRequest{
      org_id: params["org_id"] || "",
      project_id: params["project_id"] || "",
      filters: build_filters(params)
    }
    |> ToTuple.ok()
  end

  def form_list_flaky_history_request(_), do: ToTuple.internal_error("Internal error")

  @spec form_list_disruption_history_request(map()) ::
          {:ok, ListDisruptionHistoryRequest.t()} | {:error, any()}
  def form_list_disruption_history_request(params) when is_map(params) do
    %ListDisruptionHistoryRequest{
      org_id: params["org_id"] || "",
      project_id: params["project_id"] || "",
      filters: build_filters(params)
    }
    |> ToTuple.ok()
  end

  def form_list_disruption_history_request(_), do: ToTuple.internal_error("Internal error")

  @spec build_filters(map()) :: String.t()
  def build_filters(params) do
    @filter_map
    |> Enum.reduce([], fn {param, key}, acc ->
      case Map.get(params, param) do
        v when is_binary(v) and v != "" -> ["#{key}:#{encode_filter_value(v)}" | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp encode_filter_value(v) do
    safe = v |> String.replace(~s("), "") |> String.replace("@", "")
    ~s("#{safe}")
  end

  defp page(params), do: int_or_default(params["page"], 1)

  defp page_size(params, default \\ 20),
    do: min(int_or_default(params["page_size"], default), 100)

  defp int_or_default(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp int_or_default(_, default), do: default

  defp sort_dir(%{"sort_dir" => "asc"}), do: 0
  defp sort_dir(%{"sort_dir" => "desc"}), do: 1
  defp sort_dir(_), do: 1
end
