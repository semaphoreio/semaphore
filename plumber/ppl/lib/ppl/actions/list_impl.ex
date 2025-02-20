defmodule Ppl.Actions.ListImpl do
  @moduledoc """
  Module which implements List pipelines action
  """

  alias Ppl.Ppls.Model.PplsQueries
  alias LogTee, as: LT
  alias Util.ToTuple
  alias Google.Protobuf.Timestamp
  alias InternalApi.Plumber.GitRefType
  alias Util.Proto

  def list_ppls(request) do
    with tf_map                     <- %{Timestamp => {__MODULE__, :timestamp_to_datetime},
                                         GitRefType => {__MODULE__, :atom_to_lower_string}},
         {:ok, params}              <- Proto.to_map(request, transformations: tf_map),
         {:ok, project_id}          <- non_empty_value_or_default(params, :project_id, :skip),
         {:ok, wf_id}               <- non_empty_value_or_default(params, :wf_id, :skip),
         true                       <- either_project_or_wf_id_present(project_id, wf_id),
         {:ok, branch_name}         <- non_empty_value_or_default(params, :branch_name, :skip),
         {:ok, yml_file_path}       <- non_empty_value_or_default(params, :yml_file_path, :skip),
         {:ok, label}               <- non_empty_value_or_default(params, :label, :skip),
         {:ok, git_ref_types}       <- non_empty_value_or_default(params, :git_ref_types, :skip),
         {:ok, queue_id}            <- non_empty_value_or_default(params, :queue_id, :skip),
         {:ok, pr_head_branch}      <- non_empty_value_or_default(params, :pr_head_branch, :skip),
         {:ok, pr_target_branch}    <- non_empty_value_or_default(params, :pr_target_branch, :skip),
         {:ok, page}                <- non_empty_value_or_default(params, :page, 1),
         {:ok, page_size}           <- non_empty_value_or_default(params, :page_size, 30),
         {:ok, timestamps}          <- validate_timestamps(params),
         query_params               <- %{project_id: project_id, yml_file_path: yml_file_path,
                                         wf_id: wf_id, branch_name: branch_name, label: label,
                                         git_ref_types: git_ref_types, queue_id: queue_id,
                                         pr_head_branch: pr_head_branch, pr_target_branch: pr_target_branch},
         query_params               <- query_params |> Map.merge(timestamps),
         {:ok, result_page}         <- do_listing(query_params, page, page_size)
    do
      {:ok, result_page}
    else
      e ->
        LT.error(e, "List pipelines request failure")
    end
  end

  defp do_listing(params = %{
    queue_id: :skip, label: :skip, git_ref_types: :skip,
    wf_id: :skip, done_before: :skip, done_after: :skip,
    pr_head_branch: :skip, pr_target_branch: :skip}, page, page_size
  ) do
    PplsQueries.list_using_pipelines_only(params, page, page_size)
  end
  defp do_listing(params = %{
    queue_id: :skip, label: :skip , git_ref_types: :skip, wf_id: :skip, done_before: :skip,
    done_after: :skip}, page, page_size) do
    PplsQueries.list_using_requests_only(params, page, page_size)
  end
  defp do_listing(query_params, page, page_size) do
    PplsQueries.list_ppls(query_params, page, page_size)
  end

  def timestamp_to_datetime(_name, %{nanos: 0, seconds: 0}), do: :skip
  def timestamp_to_datetime(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  def atom_to_lower_string(_name, value) do
    value |> GitRefType.key() |> Atom.to_string() |> String.downcase()
  end

  def validate_timestamps(params, invalid_arg \\ false) do
    {:ok, params}
    |> date_times_or_default()
    |> first_before_second(:created_after, :created_before)
    |> first_before_second(:done_after, :done_before)
    |> first_two_before_third(:created_after, :created_before, :done_after)
    |> first_two_before_third(:created_after, :created_before, :done_before)
    |> extract_timestamps(invalid_arg)
  end

  @query_ts_names ~w(created_before created_after done_before done_after)a

  defp date_times_or_default({:ok, map}) do
    timestamps =
      Enum.into(@query_ts_names, %{}, fn key ->
        {key, datetime_or_skip(map, key)}
      end)
    map |> Map.merge(timestamps) |> ToTuple.ok()
  end

  defp datetime_or_skip(map, key) do
    case Map.get(map, key) do
      nil -> :skip
      value = %DateTime{} -> value
      _ -> :skip
    end
  end

  def first_before_second({:ok, map}, key_1, key_2) do
    case {Map.get(map, key_1), Map.get(map, key_2)} do
      {:skip, :skip} -> {:ok, map}
      {:skip, _ts_2} -> {:ok, map}
      {_ts_1, :skip} -> {:ok, map}
      {ts_1, ts_2} -> compare_two_dates({ts_1, ts_2}, map, key_1, key_2)
    end
  end
  def first_before_second(e = {:error, _msg}, _key_1, _key_2), do: e

  defp first_two_before_third({:ok, map}, key_1, key_2, key_3) do
    case {Map.get(map, key_1), Map.get(map, key_2), Map.get(map, key_3)} do
      {:skip, :skip, _ts_3} -> {:ok, map}
      {_ts_1, _ts_2, :skip} -> {:ok, map}
      {ts_1, :skip, ts_3} -> compare_two_dates({ts_1, ts_3}, map, key_1, key_3)
      {_ts_1, ts_2, ts_3} -> compare_two_dates({ts_2, ts_3}, map, key_2, key_3)
    end
  end
  defp first_two_before_third(e = {:error, _msg}, _key_1, _key_2, _key_3), do: e

  defp compare_two_dates({ts_1, ts_2}, map, key_1, key_2) do
    if DateTime.compare(ts_1, ts_2) == :lt do
      {:ok, map}
    else
      {:error, {:invalid_arg, "Inavlid values od fields '#{key_1}' and '#{key_2}'"
                               <> " - first has to be before second."}}
    end
  end

  def extract_timestamps({:ok, map}, _invalid_arg) do
    map |> Map.take(@query_ts_names) |> ToTuple.ok()
  end
  def extract_timestamps({:error, {:invalid_arg, msg}}, false),
    do: {:error, msg}
  def extract_timestamps(e = {:error, _msg}, _invalid_arg), do: e

  def either_project_or_wf_id_present(project_id, wf_id, error_atom \\ "")
  def either_project_or_wf_id_present(:skip, :skip, error_atom) do
    "Either 'project_id' or 'wf_id' parameters are required."
    |> ToTuple.error(error_atom)
  end
  def either_project_or_wf_id_present(_project_id, _wf_id, _err_a), do: true

  def non_empty_value_or_default(map, key, default) do
    case Map.get(map, key) do
      val when is_integer(val) and val > 0 -> {:ok, val}
      val when is_binary(val) and val != "" -> {:ok, val}
      val when is_list(val) and length(val) > 0 -> {:ok, val}
      _ -> {:ok, default}
    end
  end
end
