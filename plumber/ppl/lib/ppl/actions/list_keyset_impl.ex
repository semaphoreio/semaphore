defmodule Ppl.Actions.ListKeysetImpl do
  @moduledoc """
  Module which implements ListKeyset pipelines action
  """

  alias Ppl.Ppls.Model.PplsQueries
  alias LogTee, as: LT
  alias Google.Protobuf.Timestamp
  alias InternalApi.Plumber.GitRefType
  alias Util.Proto

  import Ppl.Actions.ListImpl,
    only: [validate_timestamps: 2, either_project_or_wf_id_present: 3, non_empty_value_or_default: 3]

  def list_keyset(request) do
    with tf_map                     <- %{Timestamp => {Ppl.Actions.ListImpl, :timestamp_to_datetime},
                                         GitRefType => {Ppl.Actions.ListImpl, :atom_to_lower_string}},
         {:ok, params}              <- Proto.to_map(request, transformations: tf_map),
         {:ok, project_id}          <- non_empty_value_or_default(params, :project_id, :skip),
         {:ok, wf_id}               <- non_empty_value_or_default(params, :wf_id, :skip),
         true                       <- either_project_or_wf_id_present(project_id, wf_id, :invalid_arg),
         {:ok, yml_file_path}       <- non_empty_value_or_default(params, :yml_file_path, :skip),
         {:ok, label}               <- non_empty_value_or_default(params, :label, :skip),
         {:ok, git_ref_types}       <- non_empty_value_or_default(params, :git_ref_types, :skip),
         {:ok, queue_id}            <- non_empty_value_or_default(params, :queue_id, :skip),
         {:ok, pr_head_branch}      <- non_empty_value_or_default(params, :pr_head_branch, :skip),
         {:ok, pr_target_branch}    <- non_empty_value_or_default(params, :pr_target_branch, :skip),
         {:ok, timestamps}          <- validate_timestamps(params, true),
         query_params               <- %{project_id: project_id, yml_file_path: yml_file_path,
                                         wf_id: wf_id, label: label, git_ref_types: git_ref_types,
                                         queue_id: queue_id, pr_head_branch: pr_head_branch,
                                         pr_target_branch: pr_target_branch},
         query_params               <- query_params |> Map.merge(timestamps),
         {:ok, size}                <- non_empty_value_or_default(params, :page_size, 30),
         {:ok, token}               <- non_empty_value_or_default(params, :page_token, nil),
         keyset_params              <- %{page_token: token, direction: params.direction,
                                         page_size: size, order: params.order},
         {:ok, result_page}         <- do_listing(query_params, keyset_params)
    do
      {:ok, result_page}
    else
      e ->
        LT.error(e, "ListKeyset pipelines request failure")
    end
  end

  defp do_listing(params = %{
    queue_id: :skip, git_ref_types: ref_types, wf_id: :skip, label: label,
    done_before: :skip, done_after: :skip,
    pr_head_branch: :skip, pr_target_branch: :skip}, keyset_params
  ) when (is_list(ref_types) and length(ref_types) == 1 and label != :skip) or
          (ref_types == :skip and label == :skip) do
    params
    |> prepare_branch_name(ref_types, label)
    |> PplsQueries.list_keyset_using_pipelines_only(keyset_params)
  end
  defp do_listing(params = %{
    queue_id: :skip, git_ref_types: :skip, wf_id: :skip, label:  :skip,
    done_before: :skip, done_after: :skip}, keyset_params
  ) do
    PplsQueries.list_keyset_using_requests_only(params, keyset_params)
  end
  defp do_listing(query_params, keyset_params) do
    PplsQueries.list_keyset(query_params, keyset_params)
  end

  defp prepare_branch_name(map, ["branch"], label),
    do: Map.put(map, :branch_name, label)
  defp prepare_branch_name(map, ["tag"], label),
    do: Map.put(map, :branch_name, "refs/tags/" <> label)
  defp prepare_branch_name(map, ["pr"], label),
    do: Map.put(map, :branch_name, "pull-request-" <> label)
  defp prepare_branch_name(map, _ref_type, _label),
    do: Map.put(map, :branch_name, :skip)
end
