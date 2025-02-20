defmodule Ppl.Actions.ListGroupedImpl do
  @moduledoc """
  Module which implements List grouped action
  """

  alias InternalApi.Plumber.QueueType
  alias Ppl.Ppls.Model.Triggerer
  alias Util.{Proto, ToTuple}
  alias Ppl.EctoRepo, as: Repo

  import Ppl.Actions.ListImpl, only: [non_empty_value_or_default: 3]

  def list_grouped(request) do
    with tf_map            <- %{QueueType => {__MODULE__, :list_to_string}},
         {:ok, params}     <- Proto.to_map(request, transformations: tf_map),
         {:ok, project_id} <- non_empty_value_or_default(params, :project_id, :skip),
         {:ok, org_id}     <- non_empty_value_or_default(params, :organization_id, :skip),
         queue_type        <- set_type(params.queue_type),
         true              <- required_fields_present?(queue_type, project_id, org_id),
         {:ok, page}       <- non_empty_value_or_default(params, :page, 1),
         {:ok, page_size}  <- non_empty_value_or_default(params, :page_size, 30),
         query_params      <- %{project_id: project_id, type: queue_type, org_id: org_id},
         {:ok, result}     <- list_grouped_sql(query_params, page, page_size)
    do
      {:ok, result}
    else
      e = {:error, _msg} -> e
      error -> {:error, error}
    end
  end

  def list_to_string(_name, value) do
    value |> QueueType.key() |> Atom.to_string() |> String.downcase()
  end

  defp set_type(list) when list == [], do: :skip
  defp set_type(list) when length(list) == 1, do: Enum.at(list, 0)
  defp set_type(list) when length(list) > 1, do: "all"

  defp required_fields_present?(:skip, _project_id, _org_id),
    do: {:error, "The 'queue_types' list in request must have at least one elemet."}
  defp required_fields_present?(_type, :skip, :skip),
    do: {:error, "Either 'project_id' or 'organization_id' parameters are required."}
  defp required_fields_present?(_type, _project_id, _org_id), do: true

  @doc """
  Returns one latest pipeline per queue for given project or organization
  """
  def list_grouped_sql(params, page, page_size) do
    with {:ok, count} <- list_grouped_sql_count(params),
         {:ok, ppls}  <- list_grouped_sql_paginated(params, page, page_size),
         total_pages  <- count / page_size |> Float.ceil() |> Kernel.trunc()
    do
      %{pipelines: ppls, page_number: page, page_size: page_size,
        total_entries: count, total_pages: total_pages} |> ToTuple.ok()
    else
      e = {:error, _e} -> e
      error -> {:error, error}
    end
  end

  defp list_grouped_sql_count(params) do
    """
    SELECT COUNT(o.*) FROM (
      #{list_grouped_sql_base(params)}
    ) as o;
    """
    |> Repo.query([])
    |> extract_count()
  end

  defp list_grouped_sql_paginated(params, page, page_size) do
    """
    #{list_grouped_sql_base(params)}
    LIMIT #{page_size}
    OFFSET #{(page - 1) * page_size};
    """
    |> Repo.query([])
    |> to_maps()
  end

  defp list_grouped_sql_base(params) do
    """
    SELECT *
    FROM (
      SELECT
        #{select_pipeline_details_raw_sql()}
        row_number()
          OVER(PARTITION BY p.queue_id ORDER BY p.inserted_at DESC) AS rn
      FROM  pipelines as p
        INNER JOIN pipeline_traces AS pt ON p.ppl_id = pt.ppl_id
        INNER JOIN pipeline_requests AS pr ON p.ppl_id = pr.id
        LEFT OUTER JOIN queues as q ON p.queue_id::text = q.queue_id::text
      WHERE
        #{project_or_org_switch_query(params.project_id, params.org_id)}
        #{queue_type_switch_query(params.type)}
    ) sub
    WHERE  sub.rn = 1
    ORDER BY sub.created_at DESC
    """
  end

  defp select_pipeline_details_raw_sql() do
    "
    p.ppl_id::text,
    coalesce(nullif(p.name, ''), 'Pipeline') AS name,
    p.project_id,
    p.branch_name,
    p.commit_sha,
    EXTRACT(epoch FROM pt.created_at) AS created_at,
    EXTRACT(epoch FROM pt.pending_at) AS pending_at,
    EXTRACT(epoch FROM pt.queuing_at) AS queuing_at,
    EXTRACT(epoch FROM pt.running_at) AS running_at,
    EXTRACT(epoch FROM pt.stopping_at) AS stopping_at,
    EXTRACT(epoch FROM pt.done_at) AS done_at,
    p.state,
    p.result,
    p.result_reason,
    COALESCE(NULLIF(p.terminate_request, ''), '') AS terminate_request,
    COALESCE(NULLIF(p.terminated_by, ''), '') AS terminated_by,
    pr.request_args->>'hook_id' AS hook_id,
    pr.request_args->>'branch_id' AS branch_id,
    p.error_description,
    COALESCE(NULLIF(pr.switch_id, ''), '') AS switch_id,
    COALESCE(NULLIF(pr.request_args->>'working_dir', ''), '/') AS working_directory ,
    COALESCE(NULLIF(pr.request_args->>'file_name', ''), '.semaphore.yml') AS yaml_file_name,
    pr.wf_id,
    COALESCE(NULLIF(pr.request_args->>'snapshot_id', ''), '') AS snapshot_id,
    COALESCE(NULLIF(q.queue_id::text, ''), '') AS queue_queue_id,
    COALESCE(NULLIF(q.name, ''), '') AS queue_name,
    CASE q.user_generated WHEN true THEN 'user_generated' ELSE 'implicit' END AS queue_type,
    COALESCE(NULLIF(q.scope, ''), '') AS queue_scope,
    COALESCE(NULLIF(q.project_id, ''), '') AS queue_project_id,
    COALESCE(NULLIF(q.organization_id, ''), '') AS queue_organization_id,
    pr.initial_request AS triggerer_initial_request,
    COALESCE(NULLIF(pr.request_args->>'hook_id', ''), '') AS triggerer_hook_id,
    COALESCE(NULLIF(pr.source_args->>'repo_host_uid', ''), '') AS triggerer_provider_uid,
    COALESCE(NULLIF(pr.source_args->>'repo_host_username', ''), '') AS triggerer_provider_author,
    COALESCE(NULLIF(pr.source_args->>'repo_host_avatar_url', ''), '') AS triggerer_provider_avatar,
    COALESCE(NULLIF(pr.request_args->>'triggered_by', ''), '') AS triggerer_triggered_by,
    CASE pr.request_args->>'auto_promoted' WHEN 'true' THEN true ELSE false END AS triggerer_auto_promoted,
    COALESCE(NULLIF(pr.request_args->>'promoter_id', ''), '') AS triggerer_promoter_id,
    COALESCE(NULLIF(pr.request_args->>'requester_id', ''), '') AS triggerer_requester_id,
    COALESCE(NULLIF(pr.request_args->>'scheduler_task_id', ''), '') AS triggerer_scheduler_task_id,
    COALESCE(NULLIF(pr.request_args->>'partially_rerun_by', ''), '') AS triggerer_partially_rerun_by,
    COALESCE(NULLIF(p.partial_rebuild_of, ''), '') AS triggerer_partial_rerun_of,
    COALESCE(NULLIF(p.extension_of, ''), '') AS triggerer_promotion_of,
    COALESCE(NULLIF(pr.request_args->>'wf_rebuild_of', ''), '') AS triggerer_wf_rebuild_of,
    pr.wf_id AS triggerer_workflow_id,
    COALESCE(NULLIF(pr.request_args->>'organization_id', ''), '') AS organization_id,
    "
  end

  defp project_or_org_switch_query(project_id, :skip) do
    "q.scope = 'project' AND q.project_id = '#{project_id}'"
  end

  defp project_or_org_switch_query(:skip, org_id) do
    "q.scope = 'organization' AND q.organization_id = '#{org_id}'"
  end

  defp project_or_org_switch_query(project_id, org_id) do
    "((q.scope = 'project' AND q.project_id = '#{project_id}')
     OR (q.scope = 'organization' AND q.organization_id = '#{org_id}'))"
  end

  defp queue_type_switch_query("implicit") do
    "AND q.user_generated = false"
  end
  defp queue_type_switch_query("user_generated") do
    "AND q.user_generated = true"
  end
  defp queue_type_switch_query(_type), do: ""

  defp extract_count({:ok, %{rows: [[count]]}}), do: {:ok, count}
  defp extract_count(error), do: error

  defp to_maps({:ok, %{columns: columns, rows: rows}}) do
    rows
    |> Enum.map(fn row ->
      columns
      |> Enum.zip(row)
      |> Enum.reduce(%{"queue" => %{}, "triggerer" => %Triggerer{}}, fn {key, value}, map ->
        update_field(key, value, map)
      end)
    end)
    |> ToTuple.ok()
  end
  defp to_maps(error), do: error

  defp update_field(key, value, map) do
    case key do
      "queue_" <> field -> put_in(map, ["queue", field], value)
      "triggerer_" <> field ->
        field = String.to_existing_atom(field)
        triggerer = %{map["triggerer"] | field => value}
        put_in(map, ["triggerer"], triggerer)
      field -> Map.put(map, field, to_date_time(field, value))
    end
  end

  @timestamps ~w(created_at pending_at queuing_at running_at stopping_at done_at)

  defp to_date_time(key, unix_ts) when key in @timestamps and not is_nil(unix_ts) do
     %{
      "seconds" => Kernel.trunc(unix_ts),
      "nanos" => (unix_ts - Kernel.trunc(unix_ts)) * 1_000_000_000 |> Kernel.trunc()
      }
  end
  defp to_date_time(key, nil) when key in @timestamps,
    do: %{"seconds" => 0, "nanos" => 0}
  defp to_date_time(_key, value), do: value
end
