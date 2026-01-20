defmodule Ppl.WorkflowQueries do
  @moduledoc """
  Queries  needed for actions on Workflows
  """

  import Ecto.Query

  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.Ppls.Model.Ppls
  alias Ppl.LatestWfs.Model.LatestWfs
  alias Ppl.EctoRepo, as: Repo
  alias Util.{Metrics, ToTuple}

  @doc """
  Returns details of the workflows for given IDs
  """
  def get_workflows(workflow_ids) do
    PplRequests
    |> where([p], p.initial_request == true)
    |> where([p], p.wf_id in ^workflow_ids)
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> select_workflow_details()
    |> Repo.all()
  end

  @doc """
  Returns details of workflow with given wf_id
  """
  def get_details(wf_id) do
    PplRequests
    |> where([p], p.initial_request == true)
    |> where([p], p.wf_id == ^wf_id)
    |> select_workflow_details()
    |> Repo.one()
    |> process_details_response(wf_id)
  end

  defp process_details_response(nil, wf_id),
    do: {:error, "Workflow with id: #{wf_id} not found"}

  defp process_details_response(wf, _wf_id), do: {:ok, wf}

  @doc """
  Returns list of all distinct labels of workflows from given project
  """
  def list_labels(page, page_size, project_id) do
    from(
      p in Ppls,
      join: pr in PplRequests,
      on: p.ppl_id == pr.id
    )
    |> where([_p, pr], pr.initial_request == true)
    |> where([p], p.project_id == ^project_id)
    |> group_by([p], p.branch_name)
    |> order_by([p], desc: fragment("max(?)", p.inserted_at))
    |> select([p], p.branch_name)
    |> Repo.paginate(page: page, page_size: page_size)
    |> ToTuple.ok()
  end

  @doc """
  Returns one latest workflow per branch/tag/pull request for given project
  """
  def list_grouped(params, page, page_size) do
    with {:ok, count} <- list_grouped_sql_count(params),
         {:ok, wfs} <- list_grouped_sql_paginated(params, page, page_size),
         total_pages <- (count / page_size) |> Float.ceil() |> Kernel.trunc() do
      %{
        workflows: wfs,
        page_number: page,
        page_size: page_size,
        total_entries: count,
        total_pages: total_pages
      }
      |> ToTuple.ok()
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
    #{calc_limit(page, page_size)}
    #{add_offset(page, page_size)}
    """
    |> Repo.query([])
    |> to_maps()
  end

  defp calc_limit(nil, page_size) do
    "LIMIT #{page_size + 1}"
  end

  defp calc_limit(_page, page_size) do
    "LIMIT #{page_size}"
  end

  defp add_offset(nil, _page_size), do: ";"

  defp add_offset(page, page_size) do
    "OFFSET #{(page - 1) * page_size};"
  end

  defp keyset_pagination(%{token_vals: nil}), do: ""

  defp keyset_pagination(%{token_vals: values, direction: :NEXT}) do
    """
    AND ((sub.inserted_at = #{values.inserted_at} AND sub.id < #{values.id})
        OR (sub.inserted_at < #{values.inserted_at}))
    """
  end

  defp keyset_pagination(%{token_vals: values, direction: :PREVIOUS}) do
    """
    AND ((sub.inserted_at = #{values.inserted_at} AND sub.id > #{values.id})
        OR (sub.inserted_at > #{values.inserted_at}))
    """
  end

  defp keyset_pagination(_params), do: ""

  defp list_grouped_sql_base(params) do
    """
    SELECT *
    FROM (
      SELECT
        #{select_wf_details_raw_sql()}
        row_number()
          OVER(PARTITION BY p.label ORDER BY p.inserted_at DESC) AS rn
      FROM  pipelines as p
      JOIN  pipeline_requests as pr ON p.ppl_id = pr.id
      WHERE p.project_id = '#{params.project_id}'
        AND pr.initial_request = true
        #{git_ref_types_switch_query(params.git_ref_types)}
        #{params |> Map.get(:requester_id) |> filter_by_requester_id()}
    ) sub
    WHERE  sub.rn = 1
    #{keyset_pagination(params)}
    ORDER BY sub.created_at #{set_direction(params)}
    """
  end

  defp set_direction(%{direction: :PREVIOUS}), do: "ASC"
  defp set_direction(_params), do: "DESC"

  defp select_wf_details_raw_sql() do
    """
    p.id AS id,
    EXTRACT(epoch FROM p.inserted_at) AS inserted_at,
    pr.wf_id AS wf_id,
    p.ppl_id::text AS initial_ppl_id,
    p.project_id AS project_id,
    pr.request_args->>'hook_id' AS hook_id,
    COALESCE(NULLIF(pr.request_args->>'requester_id', ''), '') AS requester_id,
    pr.request_args->>'branch_id' AS branch_id,
    p.branch_name AS branch_name,
    p.commit_sha AS commit_sha,
    EXTRACT(epoch FROM pr.inserted_at) AS created_at,
    COALESCE(NULLIF(pr.request_args->>'triggered_by', ''), '') AS triggered_by,
    COALESCE(NULLIF(pr.request_args->>'wf_rebuild_of', ''), '') AS rerun_of,
    COALESCE(NULLIF(p.repository_id, ''), '') AS repository_id,
    COALESCE(NULLIF(pr.request_args->>'organization_id', ''), '') AS organization_id,
    """
  end

  defp filter_by_requester_id(nil), do: ""
  defp filter_by_requester_id(:skip), do: ""

  defp filter_by_requester_id(requester_id) do
    "AND pr.request_args->>'requester_id' = '#{requester_id}'"
  end

  defp git_ref_types_switch_query(:skip), do: ""

  defp git_ref_types_switch_query(types) do
    "AND pr.source_args->>'git_ref_type' IN #{types_to_values_string(types)}"
  end

  defp types_to_values_string(types) do
    joined_types = types |> Enum.map_join(", ", fn type -> "'#{type}'" end)
    "(" <> joined_types <> ")"
  end

  defp extract_count({:ok, %{rows: [[count]]}}), do: {:ok, count}
  defp extract_count(error), do: error

  defp to_maps({:ok, %{columns: columns, rows: rows}}) do
    rows
    |> Enum.map(fn row ->
      columns |> Enum.zip(row) |> Enum.into(%{}) |> to_date_time()
    end)
    |> ToTuple.ok()
  end

  defp to_maps(error), do: error

  defp to_date_time(map = %{"created_at" => unix_ts}) do
    ts = %{
      "seconds" => Kernel.trunc(unix_ts),
      "nanos" => ((unix_ts - Kernel.trunc(unix_ts)) * 1_000_000_000) |> Kernel.trunc()
    }

    map |> Map.put("created_at", ts)
  end

  defp to_date_time(map), do: map

  @doc """
  Returns one latest workflow per branch/tag/pull request for given project.
  Uses keyset pagination.
  """
  def list_grouped_ks(params, page_size) do
    with {:ok, sorted_wfs} <- list_grouped_sql_paginated(params, nil, page_size),
         {:ok, wfs} <- extract_result(sorted_wfs, params, page_size),
         {:ok, prev_token} <- generate_prev_token(wfs, sorted_wfs, params, page_size),
         {:ok, next_token} <- generate_next_token(wfs, sorted_wfs, params, page_size) do
      %{workflows: wfs, previous_page_token: prev_token, next_page_token: next_token}
      |> ToTuple.ok()
    else
      e = {:error, _e} -> e
      error -> {:error, error}
    end
  end

  @doc """
  Returns one latest workflow per branch/tag/pull request for given project.
  Uses keyset pagination.
  """
  def list_latest_workflows(params = %{requester_id: nil}) do
    Metrics.benchmark("WorkflowPB.queries", "projet_page", fn ->
      list_latest_workflows_(params)
    end)
  end

  def list_latest_workflows(params = %{requester_id: requester_id})
      when is_binary(requester_id) do
    Metrics.benchmark("WorkflowPB.queries", "projet_page_for_user", fn ->
      list_latest_workflows_(params)
    end)
  end

  def list_latest_workflows(params) do
    list_latest_workflows_(params)
  end

  def list_latest_workflows_(params) do
    # We have to perform a different kind of query
    # in case requester_id is present because the
    # field doesn't exist in latest_workflows table.
    if params[:requester_id] do
      execute_slow_list_latest_workflows_query(params)
    else
      execute_fast_list_latest_workflows_query(params)
    end
  end

  defp execute_fast_list_latest_workflows_query(params) do
    query =
      LatestWfs
      |> where([wfs], wfs.project_id == ^params.project_id)
      |> order_by([wfs], desc: wfs.updated_at, desc: wfs.id)

    query =
      if params[:git_ref_types] do
        query
        |> where(
          [wfs],
          wfs.git_ref_type in ^params.git_ref_types
        )
      else
        query
      end

    page = query |> paginate(params, [:updated_at, :id])

    workflows = page.entries |> Enum.map(fn entry -> entry.wf_id end) |> get_workflows()

    {:ok,
     %{
       workflows: workflows,
       next_page_token: page.metadata.after || "",
       previous_page_token: page.metadata.before || ""
     }}
  end

  defp execute_slow_list_latest_workflows_query(params) do
    query =
      from(
        l in LatestWfs,
        inner_join: pr in PplRequests,
        on: pr.wf_id == l.wf_id,
        inner_join: p in Ppls,
        on: p.ppl_id == pr.id
      )
      |> where([_l, pr, _p], pr.initial_request == true)
      |> where([l, _pr, _p], l.project_id == ^params.project_id)
      |> order_by([l, _pr, _p], desc: l.updated_at, desc: l.id)
      |> select(
        [l, pr, p],
        %{
          ppl_id: p.id,
          id: l.id,
          updated_at: l.updated_at,
          inserted_at: p.inserted_at,
          wf_id: pr.wf_id,
          initial_ppl_id: p.ppl_id,
          project_id: p.project_id,
          hook_id: fragment("?->>?", pr.request_args, "hook_id"),
          requester_id:
            fragment(
              "coalesce(nullif(?, ''), '')",
              fragment("?->>?", pr.request_args, "requester_id")
            ),
          branch_id: fragment("?->>?", pr.request_args, "branch_id"),
          branch_name: p.branch_name,
          commit_sha: p.commit_sha,
          created_at: pr.inserted_at,
          triggered_by:
            fragment(
              "coalesce(nullif(?, ''), '')",
              fragment("?->>?", pr.request_args, "triggered_by")
            ),
          rerun_of:
            fragment(
              "coalesce(nullif(?, ''), '')",
              fragment("?->>?", pr.request_args, "wf_rebuild_of")
            ),
          repository_id:
            fragment(
              "coalesce(nullif(?, ''), '')",
              p.repository_id
            ),
          organization_id:
            fragment(
              "coalesce(nullif(?, ''), '')",
              fragment("?->>?", pr.request_args, "organization_id")
            )
        }
      )

    query =
      if params[:requester_id] do
        query
        |> where(
          [_p, pr, _l],
          fragment("?->>?", pr.request_args, "requester_id") == ^params.requester_id
        )
      else
        query
      end

    query =
      if params[:git_ref_types] do
        query
        |> where(
          [_p, pr, _l],
          fragment("?->>?", pr.source_args, "git_ref_type") in ^params.git_ref_types
        )
      else
        query
      end

    page =
      query
      |> paginate(params, [:updated_at, :id])

    workflows =
      page.entries
      |> Enum.map(fn wf ->
        wf
        |> Map.put(:id, wf.ppl_id)
        |> Map.drop([:ppl_id, :updated_at])
      end)

    {:ok,
     %{
       workflows: workflows,
       next_page_token: page.metadata.after || "",
       previous_page_token: page.metadata.before || ""
     }}
  end

  defp extract_result(results, %{direction: :NEXT}, page_size) do
    results |> Enum.take(page_size) |> ToTuple.ok()
  end

  defp extract_result(results, %{direction: :PREVIOUS}, page_size) do
    results |> Enum.take(page_size) |> Enum.reverse() |> ToTuple.ok()
  end

  defp generate_prev_token([], [], _params, _page_size), do: {:ok, ""}
  defp generate_prev_token(_, _, %{token_vals: nil}, _page_size), do: {:ok, ""}

  defp generate_prev_token(wfs, _, %{direction: :NEXT}, _page_size) do
    wfs |> List.first() |> create_token()
  end

  defp generate_prev_token(wfs, sorted_wfs, %{direction: :PREVIOUS}, page_size) do
    if first_page?(sorted_wfs, page_size) do
      {:ok, ""}
    else
      wfs |> List.first() |> create_token()
    end
  end

  defp first_page?(sorted_wfs, page_size) do
    Enum.count(sorted_wfs) <= page_size
  end

  defp create_token(nil), do: {:ok, ""}

  defp create_token(%{"id" => id, "inserted_at" => inserted_at}) do
    %{id: id, inserted_at: inserted_at}
    |> Paginator.cursor_for_record([:id, :inserted_at])
    |> ToTuple.ok()
  end

  defp generate_next_token([], [], _params, _page_size), do: {:ok, ""}

  defp generate_next_token(wfs, sorted_wfs, %{direction: :NEXT}, page_size) do
    if last_page?(sorted_wfs, page_size) do
      {:ok, ""}
    else
      wfs |> List.last() |> create_token()
    end
  end

  defp generate_next_token(wfs, _, %{direction: :PREVIOUS}, _page_size) do
    wfs |> List.last() |> create_token()
  end

  defp last_page?(sorted_wfs, page_size) do
    Enum.count(sorted_wfs) <= page_size
  end

  @doc """
  Returns list containing a maps with workflow data for each workflow
  which matches given filter params
  """
  def list_workflows(params, page, page_size) do
    PplRequests
    |> where([p], p.initial_request)
    |> filter_by_organization_id(params.org_id)
    |> filter_by_projects(params.projects)
    |> filter_by_project_id(params.project_id)
    |> filter_by_requester_id(params.requester_id)
    |> filter_by_branch(params.branch_name)
    |> filter_by_label_and_git_ref_types(params.label, params.git_ref_types)
    |> filter_by_inserted_at(params.created_before, :before)
    |> filter_by_inserted_at(params.created_after, :after)
    |> order_by([p], desc: p.inserted_at)
    |> select_workflow_details()
    |> Repo.paginate(page: page, page_size: page_size)
    |> ToTuple.ok()
  end

  @doc """
  Returns list containing a maps with workflow data for each workflow
  which matches given filter params. Result is paginated using keyset
  and page that matches given keyset_params is returned
  """
  def list_keyset(params = %{requester_id: requester_id, projects: projects}, keyset_params)
      when is_binary(requester_id) and is_list(projects) do
    Metrics.benchmark("WorkflowPB.queries", "my_work_legacy", fn ->
      list_keyset_(params, keyset_params)
    end)
  end

  def list_keyset(params = %{requesters: requesters, projects: projects}, keyset_params)
      when is_list(requesters) and is_list(projects) do
    Metrics.benchmark("WorkflowPB.queries", "my_work", fn ->
      list_keyset_(params, keyset_params)
    end)
  end

  def list_keyset(params = %{requesters: :skip, projects: projects}, keyset_params)
      when is_list(projects) do
    Metrics.benchmark("WorkflowPB.queries", "everyones", fn ->
      list_keyset_(params, keyset_params)
    end)
  end

  def list_keyset(
        params = %{requesters: :skip, project_id: project_id, branch_name: branch_name},
        keyset_params
      )
      when is_binary(branch_name) and is_binary(project_id) do
    Metrics.benchmark("WorkflowPB.queries", "branch_page", fn ->
      list_keyset_(params, keyset_params)
    end)
  end

  def list_keyset(params, keyset_params) do
    list_keyset_(params, keyset_params)
  end

  defp list_keyset_(params, keyset_params) do
    query =
      build_list_keyset_query(params)
      |> select_workflow_details()

    page = execute_paginated_query(query, keyset_params, params.projects)

    {:ok,
     %{
       workflows: page.entries,
       next_page_token: page.metadata.after || "",
       previous_page_token: page.metadata.before || ""
     }}
  end

  # For large project lists, disable hash/merge joins to force nested loop + index usage
  defp execute_paginated_query(query, keyset_params, projects)
       when is_list(projects) and length(projects) > 100 do
    {:ok, page} =
      Repo.transaction(fn ->
        Repo.query!("SET LOCAL enable_hashjoin = off")
        Repo.query!("SET LOCAL enable_mergejoin = off")
        paginate(query, keyset_params)
      end)

    page
  end

  defp execute_paginated_query(query, keyset_params, _projects) do
    paginate(query, keyset_params)
  end

  @doc """
  Builds the list_keyset query without executing it.
  """
  def build_list_keyset_query(params) do
    PplRequests
    |> where([p], p.initial_request)
    |> filter_by_organization_id(params.org_id)
    |> filter_by_projects(params.projects)
    |> filter_by_project_id(params.project_id)
    |> filter_by_requesters(params.requesters)
    |> filter_by_requester_id(params.requester_id)
    |> filter_by_branch(params.branch_name)
    |> filter_by_label_and_git_ref_types(params.label, params.git_ref_types)
    |> filter_by_triggerers(params.triggerers)
    |> filter_by_inserted_at(params.created_before, :before)
    |> filter_by_inserted_at(params.created_after, :after)
    |> order_by([p], desc: p.inserted_at, desc: p.id)
  end

  def paginate(query, params, cursor_fields \\ [:inserted_at, :id])

  def paginate(query, params = %{direction: :NEXT}, cursor_fields) do
    query
    |> Repo.paginate_keyset(
      cursor_fields: cursor_fields,
      limit: params.page_size,
      after: params.page_token,
      sort_direction: :desc
    )
  end

  def paginate(query, params = %{direction: :PREVIOUS}, cursor_fields) do
    query
    |> Repo.paginate_keyset(
      cursor_fields: cursor_fields,
      limit: params.page_size,
      before: params.page_token,
      sort_direction: :desc
    )
  end

  defp filter_by_organization_id(query, :skip), do: query

  defp filter_by_organization_id(query, org_id) do
    query
    |> where([p], fragment("?->>?", p.request_args, "organization_id") == ^org_id)
  end

  defp filter_by_projects(query, :skip), do: query

  # For large project lists (>100), use JOIN with unnest to force PostgreSQL
  # to use index lookups instead of abandoning the index for a seq scan.
  # The query planner often makes poor decisions with large IN clauses.
  defp filter_by_projects(query, projects) when is_list(projects) and length(projects) > 20 do
    query
    |> join(:inner, [p], pid in fragment("SELECT unnest(?::text[]) AS project_id", ^projects),
      on: fragment("?->>? = ?", p.request_args, "project_id", pid.project_id)
    )
  end

  defp filter_by_projects(query, projects),
    do: query |> where([p], fragment("?->>?", p.request_args, "project_id") in ^projects)

  defp filter_by_project_id(query, :skip), do: query

  defp filter_by_project_id(query, project_id),
    do: query |> where([p], fragment("?->>?", p.request_args, "project_id") == ^project_id)

  defp filter_by_requesters(query, :skip), do: query

  defp filter_by_requesters(query, requesters),
    do: query |> where([p], fragment("?->>?", p.request_args, "requester_id") in ^requesters)

  defp filter_by_requester_id(query, :skip), do: query

  defp filter_by_requester_id(query, req_id) do
    query
    |> where([p], fragment("?->>?", p.request_args, "requester_id") == ^req_id)
  end

  defp filter_by_branch(query, :skip), do: query

  defp filter_by_branch(query, branch_name),
    do: query |> where([p], fragment("?->>?", p.request_args, "branch_name") == ^branch_name)

  defp filter_by_label_and_git_ref_types(query, :skip, :skip), do: query

  defp filter_by_label_and_git_ref_types(query, :skip, git_ref_types) do
    query
    |> where(
      [p],
      fragment("?->>?", p.source_args, "git_ref_type") in ^git_ref_types
    )
  end

  defp filter_by_label_and_git_ref_types(query, label, :skip) do
    branch_names = [label, "refs/tags/#{label}", "pull-request-#{label}"]
    query |> where([p], fragment("?->>?", p.request_args, "branch_name") in ^branch_names)
  end

  defp filter_by_label_and_git_ref_types(query, label, git_ref_types) do
    branch_names =
      git_ref_types
      |> Enum.map(fn git_ref_type ->
        case git_ref_type do
          "branch" -> label
          "tag" -> "refs/tag/#{label}"
          "pr" -> "pull-request-#{label}"
        end
      end)

    query |> where([p], fragment("?->>?", p.request_args, "branch_name") in ^branch_names)
  end

  defp filter_by_triggerers(query, val) when val in [:skip, []], do: query

  defp filter_by_triggerers(query, triggerers) do
    query
    |> where(
      [p],
      fragment(
        "(?->>'triggered_by' = ANY(?) OR ?->>'triggered_by' IS NULL)",
        p.request_args,
        ^triggerers,
        p.request_args
      )
    )
  end

  defp filter_by_inserted_at(query, :skip, _order), do: query

  defp filter_by_inserted_at(query, timestamp, :before),
    do: query |> where([p], p.inserted_at < ^timestamp)

  defp filter_by_inserted_at(query, timestamp, :after),
    do: query |> where([p], p.inserted_at > ^timestamp)

  defp select_workflow_details(query) do
    query
    |> select(
      [pr],
      %{
        id: pr.id,
        inserted_at: pr.inserted_at,
        wf_id: pr.wf_id,
        initial_ppl_id: pr.id,
        project_id: fragment("?->>?", pr.request_args, "project_id"),
        hook_id: fragment("?->>?", pr.request_args, "hook_id"),
        requester_id:
          fragment(
            "coalesce(nullif(?, ''), '')",
            fragment("?->>?", pr.request_args, "requester_id")
          ),
        branch_id: fragment("?->>?", pr.request_args, "branch_id"),
        branch_name: fragment("?->>?", pr.request_args, "branch_name"),
        commit_sha: fragment("?->>?", pr.request_args, "commit_sha"),
        created_at: pr.inserted_at,
        triggered_by:
          fragment(
            "coalesce(nullif(?, ''), '')",
            fragment("?->>?", pr.request_args, "triggered_by")
          ),
        rerun_of:
          fragment(
            "coalesce(nullif(?, ''), '')",
            fragment("?->>?", pr.request_args, "wf_rebuild_of")
          ),
        repository_id:
          fragment(
            "coalesce(nullif(?, ''), '')",
            fragment("?->>?", pr.request_args, "repository_id")
          ),
        organization_id:
          fragment(
            "coalesce(nullif(?, ''), '')",
            fragment("?->>?", pr.request_args, "organization_id")
          )
      }
    )
  end
end
