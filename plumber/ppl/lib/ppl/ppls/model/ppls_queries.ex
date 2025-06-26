# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Ppl.Ppls.Model.PplsQueries do
  @moduledoc """
  Pipelines Queries
  Operations on Pipelines  type

  'initializing' - initial pipeline state.
  Waiting for fetching .yml schema file and schema validation.
  From 'initializing' pipeline transitions to 'pending' or 'done'(failed or canceld)

  'pending'
  Pipeline is ready for running.
  When checked, if there are no other older pipelines from same project and branch that
  are in 'initializing', 'pending' or 'running', it to 'running', otherwise it goes
  to 'queuing' state.
  From 'pending' pipeline transitions to 'queuing', 'running' or 'done'(canceled)

  'running'
  When pipeline enters this state Pipeline Block Events entries for each pipeline's block
  are created and they start executing.
  When checked by looper:
  - If termination_request is 'stop', pipeline transitions to 'stopping'
  - If there are blocks which are running or waitng, pipeline will be fetched by
  looper later and checked again.
  - If all blocks are done, or some of them failed, it goes to 'done' state.
  From 'running' pipeline transitions to 'done' or 'stopping'

  'stopping'
  Pipelines termination is started, waiting for termination of all blocks.
  From 'stopping' pipeline transitions to 'done'(stopped).

  'done' - terminal state for Pipelines
  Pipeline execution finished.
"""

  require Ppl.Ctx

  import Ecto.Query

  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Ctx
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.PplTraces.Model.PplTraces
  alias Ppl.Ppls.Model.{Ppls, Triggerer}
  alias Block.CodeRepo.Expand
  alias Ppl.Queues.Model.Queues
  alias Util.Metrics

  @repo_fields ~w(owner repo_name branch_name commit_sha project_id label)

  def insert(ctx, partial_rebuild_of \\ "", start_in_conceived? \\ false) do
    req_args = ctx.request_args
    yml_file_path = Expand.full_name(req_args["working_dir"], req_args["file_name"])
    service = Map.get(ctx.request_args, "service")
    extension_of = Map.get(req_args, "extension_of", "")
    scheduler_task_id = Map.get(req_args, "scheduler_task_id", "")
    with_repo_data? = not start_in_conceived?

    %{ppl_id: ctx.id, yml_file_path: yml_file_path}
      |> Map.put(:state, "initializing")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:partial_rebuild_of, partial_rebuild_of)
      |> Map.put(:extension_of, extension_of)
      |> Map.put(:scheduler_task_id, scheduler_task_id)
      |> set_repo_data(service, ctx)
      |> ensure_label_is_set()
      |> insert_(ctx, service, with_repo_data?)
  end

  defp ensure_label_is_set(ppl = %{label: label}) when is_binary(label), do: ppl
  defp ensure_label_is_set(ppl = %{branch_name: branch}) do
     ppl |> Map.put(:label, branch |> to_label())
  end
  defp ensure_label_is_set(error), do: error

  defp to_label("refs/tags/" <> label), do: label
  defp to_label("pull-request-" <> label), do: label
  defp to_label(label), do: label

  defp set_repo_data(ppl, "local", ppl_req) do
    @repo_fields
    |> Enum.map(fn key -> {key, Map.get(ppl_req.request_args, key)} end)
    |> Enum.into(%{}, fn {k, v} -> random_if_not_defined(k, v) end)
    |> Map.merge(ppl_req.request_args)
    |> set_repo_data_(ppl)
  end
  defp set_repo_data(ppl, "snapshot", ppl_req), do:
    set_repo_data_(ppl_req.request_args, ppl)
  defp set_repo_data(ppl, "listener_proxy", ppl_req), do:
    set_repo_data_(ppl_req.request_args, ppl)
  defp set_repo_data(ppl, service, ppl_req) when service in ["git_hub", "bitbucket", "git", "gitlab"] do
    ppl_req.request_args
    |> Map.take(@repo_fields)
    |> keys_to_atoms()
    |> Map.put(:repository_id, Map.get(ppl_req.request_args, "repository_id"))
    |> Map.merge(ppl)
  end
  defp set_repo_data(_ppl, service, _ppl_req), do:
    {:error, {:unknown_service, service}}

  defp set_repo_data_(args, ppl) do
    args
    |> Map.take(@repo_fields)
    |> keys_to_atoms()
    |> Map.merge(ppl)
  end

  defp keys_to_atoms(map) do
    map |> Enum.into(%{}, fn {key, value} -> {String.to_atom(key), value} end)
  end

  defp random_if_not_defined("label", value), do: {"label", value}
  defp random_if_not_defined(k, value),
    do: if(is_nil(value) or value == "", do: {k, UUID.uuid4()}, else: {k, value})

  defp insert_(ppl, ctx, service, with_repo_data?) when is_map(ppl) do
    %Ppls{} |> Ppls.changeset(ppl, service == "listener_proxy", with_repo_data?) |> Repo.insert
    |> process_response(ctx.id)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end
  defp insert_(event, _ctx, _service, _with_repo_data?), do: event

  defp process_response({:error, %Ecto.Changeset{errors: [one_ppl_per_ppl_request: _message]}}, ppl_id) do
    LT.info(ppl_id, "PplsQueries.insert() - There is already pipeline for pipeline request with id:")
    get_by_id(ppl_id)
  end
  defp process_response(ppl, _ppl_id) do
    Ctx.event(ppl, "initializing")
  end

  @doc """
  Add missing repository data to pipeline
  Used by JustRun feature
  """
  def supplement_repo_data(ppl, repo_data) do
    ppl |> Ppls.changeset(repo_data) |> Repo.update()
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end


  @doc """
  Optimized version of the list keyset action for subset of requests where result
  set can be found using only the pipelines table
  """
  def list_keyset_using_pipelines_only(params, keyset_params) do
    with {:ok, result_page} <- do_optimized_list_keyset(params, keyset_params),
         ids <- Enum.map(result_page.pipelines, fn ppl -> ppl.ppl_id end),
         {:ok, pipelines}   <- get_details_for_all(ids),
    do: {:ok, %{result_page | pipelines: pipelines}}
  end

  defp do_optimized_list_keyset(params, keyset_params) do
    query =
      Ppls
      |> filter_by_project_id(params.project_id)
      |> filter_by_file_path(params.yml_file_path)
      |> filter_by_branch(params.branch_name)
      |> filter_insreted_at(params.created_before, :before)
      |> filter_insreted_at(params.created_after, :after)

    page =
      case keyset_params.order do
        :BY_CREATION_TIME_DESC ->
          list_ppl_ids_by_inserted_at_desc(query, keyset_params)
      end

    {:ok, %{pipelines: page.entries, next_page_token: page.metadata.after || "",
            previous_page_token: page.metadata.before || ""}}
  end

  defp list_ppl_ids_by_inserted_at_desc(query, keyset_params) do
    query
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> select([p], %{id: p.id, inserted_at: p.inserted_at, ppl_id: p.ppl_id})
    |> paginate(keyset_params)
  end

  @doc """
  Optimized version of the list keyset action for subset of requests where result set can
  be found using only the pipeline_requests table.
  It uses ppl_id(id in requests table) as second cursor field as oposed to id from pipelines
  table. This can only be problem if two pipelines have identiacl inserted_at value which is
  highly unlikely.
  """
  def list_keyset_using_requests_only(params, keyset_params) do
    with {:ok, result_page} <- do_list_keyset_requests_only(params, keyset_params),
          ids <- Enum.map(result_page.pipelines, fn ppl -> ppl.id end),
          {:ok, pipelines}   <- get_details_for_all(ids),
    do: {:ok, %{result_page | pipelines: pipelines}}
  end

  defp do_list_keyset_requests_only(params, keyset_params) do
    query =
      from(PplRequests, as: :pr)
      |> filter_requests_by_project_id(params.project_id)
      |> filter_requests_by_yaml_file_path(params.yml_file_path)
      |> filter_insreted_at(params.created_before, :before)
      |> filter_insreted_at(params.created_after, :after)
      |> filter_by_pr_head_branch(params.pr_head_branch)
      |> filter_by_pr_target_branch(params.pr_target_branch)
    page =
      case keyset_params.order do
        :BY_CREATION_TIME_DESC ->
          list_ids_by_inserted_at_desc(query, keyset_params)
      end

    {:ok, %{pipelines: page.entries, next_page_token: page.metadata.after || "",
            previous_page_token: page.metadata.before || ""}}
  end

  defp list_ids_by_inserted_at_desc(query, keyset_params) do
    query
    |> order_by([pr], desc: pr.inserted_at, desc: pr.id)
    |> select([pr], %{id: pr.id, inserted_at: pr.inserted_at})
    |> paginate(keyset_params)
  end

  @doc """
  Returns pipelines that match given search params paginated via keyset approach.
  """
  def list_keyset(params, keyset_params) do
    query =
      join_request_trace_and_ppl()
      |> filter_by_project_id(params.project_id)
      |> filter_by_wf_id(params.wf_id)
      |> filter_by_file_path(params.yml_file_path)
      |> filter_by_label(params.label)
      |> filter_by_git_ref_types(params.git_ref_types)
      |> filter_by_queue_id(params.queue_id)
      |> filter_by_timestamps(params)
      |> filter_by_pr_head_branch(params.pr_head_branch)
      |> filter_by_pr_target_branch(params.pr_target_branch)

    page = case keyset_params.order do
      :BY_CREATION_TIME_DESC ->
        list_ppls_by_inserted_at_desc(query, keyset_params)
    end

    {:ok, %{pipelines: page.entries, next_page_token: page.metadata.after || "",
            previous_page_token: page.metadata.before || ""}}
  end

  defp list_ppls_by_inserted_at_desc(query, keyset_params) do
    query
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> select_pipeline_details()
    |> paginate(keyset_params)
  end

  defp paginate(query, params = %{direction: :NEXT}) do
    query
    |> Repo.paginate_keyset(
          cursor_fields: [:inserted_at, :id], limit: params.page_size,
          after: params.page_token, sort_direction: :desc)
  end

  defp paginate(query, params = %{direction: :PREVIOUS}) do
    query
    |> Repo.paginate_keyset(
          cursor_fields: [:inserted_at, :id], limit: params.page_size,
          before: params.page_token, sort_direction: :desc)
  end

  @doc """
  Optimized version of the list action for subset of requests where result set can
  be found using only the pipelines table.
  """
  def list_using_pipelines_only(params, page, page_size) do
    with {:ok, result_page} <- list_using_pipelines_only_(params, page, page_size),
         {:ok, pipelines}   <- get_details_for_all(result_page.entries),
    do: {:ok, %Scrivener.Page{result_page | entries: pipelines}}
  end
  def list_using_pipelines_only_(params, page, page_size) do
    Ppls
    |> filter_by_project_id(params.project_id)
    |> filter_by_branch(params.branch_name)
    |> filter_by_file_path(params.yml_file_path)
    |> filter_insreted_at(params.created_before, :before)
    |> filter_insreted_at(params.created_after, :after)
    |> order_by([p], desc: p.inserted_at)
    |> select([p], p.ppl_id)
    |> Repo.paginate(page: page, page_size: page_size)
    |> return_ok_tuple()
  end

  defp filter_insreted_at(query, :skip, _order), do: query
  defp filter_insreted_at(query, timestamp, :before),
    do: query |> where([p], p.inserted_at < ^timestamp)
  defp filter_insreted_at(query, timestamp, :after),
    do: query |> where([p], p.inserted_at > ^timestamp)

  @doc """
  Optimized version of the list action for subset of requests where result set can
  be found using only the pipeline_requests table.
  """
  def list_using_requests_only(params, page, page_size) do
    with {:ok, result_page} <- list_using_requests_(params, page, page_size),
          {:ok, pipelines}   <- get_details_for_all(result_page.entries),
    do: {:ok, %Scrivener.Page{result_page | entries: pipelines}}
  end
  def list_using_requests_(params, page, page_size) do
    from(PplRequests, as: :pr)
    |> filter_requests_by_project_id(params.project_id)
    |> filter_requests_by_yaml_file_path(params.yml_file_path)
    |> filter_insreted_at(params.created_before, :before)
    |> filter_insreted_at(params.created_after, :after)
    |> filter_by_pr_head_branch(params.pr_head_branch)
    |> filter_by_pr_target_branch(params.pr_target_branch)
    |> order_by([pr], desc: pr.inserted_at)
    |> select([pr], pr.id)
    |> Repo.paginate(page: page, page_size: page_size)
    |> return_ok_tuple()
  end

  defp filter_requests_by_project_id(query, :skip), do: query
  defp filter_requests_by_project_id(query, project_id) do
    query |> where([pr], fragment("?->>?", pr.request_args, "project_id") == ^project_id)
  end

  defp filter_requests_by_yaml_file_path(query, :skip), do: query
  defp filter_requests_by_yaml_file_path(query, yml_file_path) do
    dir = Path.dirname(yml_file_path)
    file = Path.basename(yml_file_path)

    query
    |> where([pr], fragment("? ->>?", pr.request_args, "working_dir") == ^dir)
    |> where([pr], fragment("? ->> ?", pr.request_args, "file_name" ) == ^file)
  end

  @doc """
  Returns list containing a map containing pipelines data for each pipeline from
  given branch of given project.
  """
  def list_ppls(params, page, page_size) do
    join_request_trace_and_ppl()
    |> filter_by_project_id(params.project_id)
    |> filter_by_branch(params.branch_name)
    |> filter_by_label(params.label)
    |> filter_by_git_ref_types(params.git_ref_types)
    |> filter_by_file_path(params.yml_file_path)
    |> filter_by_wf_id(params.wf_id)
    |> filter_by_queue_id(params.queue_id)
    |> filter_by_pr_head_branch(params.pr_head_branch)
    |> filter_by_pr_target_branch(params.pr_target_branch)
    |> filter_by_timestamps(params)
    |> order_by([p], desc: p.inserted_at)
    |> select_pipeline_details()
    |> Repo.paginate(page: page, page_size: page_size)
    |> return_ok_tuple()
  end

  def join_request_trace_and_ppl() do
    from(
      p in Ppls,
      join: pt in PplTraces, on: p.ppl_id == pt.ppl_id,
      join: pr in PplRequests, on: p.ppl_id == pr.id, as: :pr,
      left_join: q in Queues, on: fragment("?::uuid=?", p.queue_id, q.queue_id))
  end

  defp filter_by_project_id(query, :skip), do: query
  defp filter_by_project_id(query, project_id),
    do: query |> where([p], p.project_id == ^project_id)

  defp filter_by_branch(query, :skip), do: query
  defp filter_by_branch(query, branch_name),
    do: query |> where([p], p.branch_name == ^branch_name)

  defp filter_by_file_path(query, :skip), do: query
  defp filter_by_file_path(query, yml_file_path),
    do: query |> where([p], p.yml_file_path == ^yml_file_path)

  defp filter_by_wf_id(query, :skip), do: query
  defp filter_by_wf_id(query, wf_id),
    do: query |> where([_p, _pt, pr], pr.wf_id == ^wf_id)

  defp filter_by_queue_id(query, :skip), do: query
  defp filter_by_queue_id(query, queue_id),
    do: query |> where([_p, _pt, _pr, q], fragment("?::text=?::text", q.queue_id , ^queue_id))

  defp filter_by_label(query, :skip), do: query
  defp filter_by_label(query, label),
    do: query |> where([p], p.label == ^label)

  defp filter_by_git_ref_types(query, :skip), do: query
  defp filter_by_git_ref_types(query, ref_types) do
    query |> where([_p, _pt, pr],
                fragment("?->>?", pr.source_args, "git_ref_type") in ^ref_types)
  end

  defp filter_by_timestamps(query, params) do
    query
    |> filter_created_at(params.created_before, :before)
    |> filter_created_at(params.created_after, :after)
    |> filter_done_at(params.done_before, :before)
    |> filter_done_at(params.done_after, :after)
  end

  defp filter_created_at(query, :skip, _order), do: query
  defp filter_created_at(query, timestamp, :before),
    do: query |> where([_p, pt], pt.created_at < ^timestamp)
  defp filter_created_at(query, timestamp, :after),
    do: query |> where([_p, pt], pt.created_at > ^timestamp)

  defp filter_done_at(query, :skip, _order), do: query
  defp filter_done_at(query, timestamp, :before) do
    query
    |> where([p], p.state == "done")
    |> where([_p, pt], pt.done_at < ^timestamp)
  end
  defp filter_done_at(query, timestamp, :after) do
    query
    |> where([p], p.state == "done")
    |> where([_p, pt], pt.done_at > ^timestamp)
  end

  defp filter_by_pr_head_branch(query, :skip), do: query
  defp filter_by_pr_head_branch(query, pr_head_branch) do
    query
    |> where([pr: pr], fragment("?->>?", pr.source_args, "git_ref_type") == "pr")
    |> where([pr: pr], fragment("?->>?", pr.source_args, "pr_branch_name") == ^pr_head_branch)
  end

  defp filter_by_pr_target_branch(query, :skip), do: query
  defp filter_by_pr_target_branch(query, pr_target_branch) do
    query
    |> where([pr: pr], fragment("?->>?", pr.source_args, "git_ref_type") == "pr")
    |> where([pr: pr], fragment("?->>?", pr.source_args, "branch_name") == ^pr_target_branch)
  end

  defp select_pipeline_details(query) do
    query
    |> select([p, pt, pr, q],
        %{
          id: p.id,
          inserted_at: p.inserted_at,
          ppl_id: p.ppl_id,
          name: fragment("coalesce(nullif(?, ''), 'Pipeline')", p.name),
          organization_id: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "organization_id")),
          project_id: p.project_id,
          branch_name: p.branch_name,
          commit_sha: fragment("coalesce(nullif(?, ''), '')", p.commit_sha),
          created_at: pt.created_at,
          pending_at: pt.pending_at,
          queuing_at: pt.queuing_at,
          running_at: pt.running_at,
          stopping_at: pt.stopping_at,
          done_at: pt.done_at,
          state: p.state,
          result: p.result,
          result_reason: p.result_reason,
          terminate_request: fragment("coalesce(nullif(?, ''), '')", p.terminate_request),
          terminated_by: fragment("coalesce(nullif(?, ''), '')", p.terminated_by),
          hook_id: fragment("?->>?", pr.request_args, "hook_id"),
          branch_id: fragment("?->>?", pr.request_args, "branch_id"),
          error_description: p.error_description,
          switch_id: fragment("coalesce(nullif(?, ''), '')", pr.switch_id),
          working_directory: fragment("coalesce(nullif(?, ''), '/')", fragment("?->>?", pr.request_args, "working_dir")),
          yaml_file_name: fragment("coalesce(nullif(?, ''), '.semaphore.yml')", fragment("?->>?", pr.request_args, "file_name")),
          wf_id: pr.wf_id,
          snapshot_id: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "snapshot_id")),
          promotion_of: fragment("coalesce(nullif(?, ''), '')", p.extension_of),
          partial_rerun_of: fragment("coalesce(nullif(?, ''), '')", p.partial_rebuild_of),
          partially_rerun_by: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "partially_rerun_by")),
          commit_message: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.source_args, "commit_message")),
          compile_task_id: fragment("coalesce(nullif(?, ''), '')", p.compile_task_id),
          after_task_id: fragment("coalesce(nullif(?, ''), '')", p.after_task_id),
          with_after_task: fragment("coalesce(?, false)", p.with_after_task),
          repository_id: fragment("coalesce(nullif(?, ''), '')", p.repository_id),
          queue: %{
            queue_id: fragment("coalesce(nullif(?::text, ''), '')", q.queue_id),
            name: fragment("coalesce(nullif(?, ''), '')", q.name),
            type: fragment("case ? when true then 'user_generated' else 'implicit' end", q.user_generated),
            scope: fragment("coalesce(nullif(?, ''), '')", q.scope),
            project_id: fragment("coalesce(nullif(?, ''), '')", q.project_id),
            organization_id: fragment("coalesce(nullif(?, ''), '')", q.organization_id),
          },
          env_vars: fragment("coalesce(nullif(?, ''), '[]')::json", fragment("?->>?", pr.request_args, "env_vars")),
          # Triggerer data
          triggerer: %Triggerer{
            initial_request: pr.initial_request,
            hook_id: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "hook_id")),
            provider_uid: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.source_args, "repo_host_uid")),
            provider_author: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.source_args, "repo_host_username")),
            provider_avatar: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.source_args, "repo_host_avatar_url")),
            triggered_by: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "triggered_by")),
            auto_promoted: fragment("coalesce(?, false)", fragment("(?->>?)::boolean", pr.request_args, "auto_promoted")),
            promoter_id: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "promoter_id")),
            requester_id: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "requester_id")),
            scheduler_task_id: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "scheduler_task_id")),
            partially_rerun_by: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "partially_rerun_by")),
            partial_rerun_of: fragment("coalesce(nullif(?, ''), '')", p.partial_rebuild_of),
            promotion_of: fragment("coalesce(nullif(?, ''), '')", p.extension_of),
            wf_rebuild_of: fragment("coalesce(nullif(?, ''), '')", fragment("?->>?", pr.request_args, "wf_rebuild_of")),
            workflow_id: pr.wf_id,
          }
        }
      )
  end

  @doc """
  Returns detailed pipeline data for all given ppl_ids in same order.
  """
  def get_details_for_all([]), do: {:ok, []}
  def get_details_for_all(ppl_ids) do
    join_request_trace_and_ppl()
    |> where([p], p.ppl_id in ^ppl_ids)
    |> select_pipeline_details()
    |> Repo.all()
    |> process_get_all_results(ppl_ids)
  end

  # Postgres does not guarantee the order of results, so sorting is needed
  defp process_get_all_results(results, ids),
    do: process_get_all_results_(results, ids, length(results) == length(ids))

  defp process_get_all_results_(results, ids, true) do
    results
    |> Enum.sort(fn x, y ->
      Enum.find_index(ids, &(&1 == x.ppl_id)) <= Enum.find_index(ids, &(&1 == y.ppl_id))
    end)
    |> return_ok_tuple()
  end
  defp process_get_all_results_(results, ids, false) do
    ids
    |> Enum.reduce_while(
        {:error, "Failed to find all pipelines"},
        fn ppl_id, acc -> check_if_id_is_in_resutls(results, ppl_id, acc) end
      )
  end

  defp check_if_id_is_in_resutls(results, ppl_id, acc) do
    if Enum.find(results, fn ppl -> ppl.ppl_id == ppl_id end) do
      {:cont, acc}
    else
      {:halt, {:error, "Pipeline with id: #{ppl_id} not found"}}
    end
  end

  @doc """
  Returns detailed pipeline data for pipeline with given ppl_id
  """
  def get_details(ppl_id) do
    join_request_trace_and_ppl()
    |> where([p], p.ppl_id == ^ppl_id)
    |> select_pipeline_details()
    |> Repo.one()
    |> process_details_response(ppl_id)
  end

  defp process_details_response(nil, ppl_id),
    do: {:error, "Pipeline with id: #{ppl_id} not found"}
  defp process_details_response(ppl, _ppl_id), do: {:ok, ppl}

  def all_ppls_from_same_queue_in_states(ppl, states) do
    ppls_from_same_queue_in_states_(Ppls, ppl, states)
  end

  @doc """
  Returnes distinct values for auto_cancel property of pipelines that are younger
  (scheduled after) than given pipeline. Based on this values looper can decide
  wether to continue executing given pipeline or if the auto-cancel behavior should
  be triggered.
  """
  def should_do_auto_cancel?(ppl) do
    ppl |> younger_pipelines_query() |> get_auto_cancel_type(ppl)
  end

  defp get_auto_cancel_type(query, ppl) do
    query
    # Find all ppls different from given ppl
    |> where([p], p.id != ^ppl.id)
    # Which belong to the same queue
    |> where([p], p.queue_id == ^ppl.queue_id)
    |> select([p], p.auto_cancel)
    |> distinct(true)
    |> Repo.all()
    |> auto_cancel_respone()
  end

  defp auto_cancel_respone(settings_list) when is_list(settings_list) do
    Enum.reduce_while(settings_list, {:ok, false}, fn
      "stop", _result -> {:halt, {:ok, "stop"}}
      "cancel", _result -> {:cont, {:ok, "cancel"}}
      _value, result ->  {:cont, result}
    end)
  end
  defp auto_cancel_respone(_error), do: {:ok, false}

  @doc """
  Find all pipelines different from given pipeline but from same queue which are
  in one of states from states param, and which are created before or after given
  pipeline based on value of 'older_pipelines' param.
  """
  def ppls_from_same_queue_in_states(ppl, states, older_pipelines \\ true)
  def ppls_from_same_queue_in_states(ppl, states, true) do
    ppl |> older_pipelines_query() |> ppls_from_same_queue_in_states_(ppl, states)
  end
  def ppls_from_same_queue_in_states(ppl, states, false) do
    ppl |> younger_pipelines_query() |> ppls_from_same_queue_in_states_(ppl, states)
  end

  # Find all pipelines scheduled _before_ this particular one.
  defp older_pipelines_query(ppl) do
    from(p in Ppls, where: p.inserted_at < ^ppl.inserted_at)
  end

  # Find all pipelines scheduled _after_ this particular one.
  defp younger_pipelines_query(ppl) do
    from(p in Ppls, where: p.inserted_at > ^ppl.inserted_at)
  end

  defp ppls_from_same_queue_in_states_(query, ppl, states) do
    query
    # Find all ppls different from given ppl
    |> where([p], p.id != ^ppl.id)
    # In one of states from given states list
    |> where([p], p.state in ^states)
    # Which belong to the same queue
    |> where([p], p.queue_id == ^ppl.queue_id)
    |> Repo.all()
    |> return_ok_tuple()
  end

  @doc """
  Returns number of pipelines from project with given project_id which are in one of given states.
  """
  def no_of_ppls_from_project_in_states(project_id, states) do
    Ppls
    # From project with given project_id
    |> where([p], p.project_id == ^project_id)
    # In one of states from given states list
    |> where([p], p.state in ^states)
    |> select([p], count(p.ppl_id))
    |> Repo.one()
    |> return_ok_tuple()
  rescue
    e -> {:error, e}
  end

  @doc """
  Find one pipeline from project with given project_id
  """
  def get_one_from_project(project_id) do
    Ppls
    |> where([p], p.project_id == ^project_id)
    |> limit(1)
    |> Repo.one()
    |> return_tuple({:ppl_not_found, "Pipeline from project #{project_id} is not found."})
  end

  @doc """
  Sets terminate request fields for given Ppl
  """
  def terminate(ppl, t_request, t_request_desc) do
    params = %{terminate_request: t_request, terminate_request_desc: t_request_desc}
    ppl
    |> Ppls.changeset(params)
    |> Repo.update()
  end

  @doc """
  Set termination flags for all pipelines which match given filters and are not
  in terminal state.
  """
  def terminate_all(t_params) do
    from(p in Ppls,
         join: pr in PplRequests, on: p.ppl_id == pr.id, as: :pr
    )
    |> filter_by_organization_id?(t_params)
    |> filter_by_project_id?(t_params)
    |> filter_by_branch_name?(t_params)
    |> filter_by_workflow_id?(t_params)
    |> where([p], p.state != "done")
    |> update_set([terminate_request: t_params.terminate_request])
    |> update_set([terminate_request_desc: t_params.terminate_request_desc])
    |> update_set([terminated_by: t_params.terminated_by])
    |> Repo.update_all([])
    |> return_number()
  rescue
    e -> {:error, e}
  end

  defp filter_by_project_id?(query, %{project_id: project_id}),
    do: query |> where([p], p.project_id == ^project_id)
  defp filter_by_project_id?(query, _t_params), do: query

  defp filter_by_branch_name?(query, %{branch_name: branch_name}),
    do: query |> where([p], p.branch_name == ^branch_name)
  defp filter_by_branch_name?(query, _t_params), do: query

  defp filter_by_workflow_id?(query, %{wf_id: wf_id}),
    do: query |> where([p, pr], pr.wf_id == ^wf_id)
  defp filter_by_workflow_id?(query, _t_params), do: query

  defp filter_by_organization_id?(query, %{org_id: org_id}) do
    query
    |> where([p, pr], fragment("?->>'organization_id'", pr.request_args) == ^org_id)
  end
  defp filter_by_organization_id?(query, _t_params), do: query

  defp update_set(q, fields), do: q |> update(set: ^fields)

  @doc """
  Sets 'deletion_requested' flag for all pipelines from given project.
  """
  def mark_for_deletion(project_id) do
    Ppls
    |> where([p], p.project_id == ^project_id)
    |> update_set([deletion_requested: true])
    |> Repo.update_all([])
    |> return_number()
  end

  @doc """
  Gets the number of workflows from same project and branch that were scheduled
  before the given initial pipeline.
  """
  def previous_wfs_number(ppl) do
    previous_num =
      Metrics.benchmark("Ppl.get_wf_number", ["read_from_previous"],  fn ->
        previous_wfs_number_(ppl)
      end)

    case previous_num do
      num when is_integer(num) ->
         {:ok, num}

      _other ->
        Metrics.benchmark("Ppl.get_wf_number", ["count_all"],  fn ->
          count_previous_wfs(ppl)
        end)
    end
  end

  defp previous_wfs_number_(ppl) do
    filter_previous_wfs(ppl)
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> select([p], p.wf_number)
    |> Repo.one()
  rescue
    e -> {:error, e}
  end

  defp count_previous_wfs(ppl) do
    filter_previous_wfs(ppl)
    |> select([p], count(p.id))
    |> Repo.one()
    |> return_ok_tuple()
  rescue
    e -> {:error, e}
  end

  defp filter_previous_wfs(ppl) do
    from(
      p in Ppls,
      join: pr in PplRequests, on: p.ppl_id == pr.id
    )
    |> where([p], p.project_id == ^ppl.project_id)
    |> where([p], p.branch_name == ^ppl.branch_name)
    |> where([p], p.inserted_at < ^ppl.inserted_at)
    |> where([_p, pr], pr.initial_request == true)
  end

  @doc """
  Finds initial pipeline in workflow with given id
  """
  def get_initial_wf_ppl(wf_id) do
    from(
      p in Ppls,
      join: pr in PplRequests, on: p.ppl_id == pr.id
    )
    |> where([_p, pr], pr.initial_request == true)
    |> where([_p, pr], pr.top_level == true)
    |> where([_p, pr], pr.wf_id == ^wf_id)
    |> select([p], p)
    |> Repo.one()
    |> return_tuple({:not_found, "Workflow with id: #{wf_id} not found."})
  rescue
    e -> {:error, e}
  end

  @doc """
  Find pipeline by ppl_id
  """
  def get_by_id(id) do
      Ppls |> where(ppl_id: ^id) |> Repo.one()
      |> return_tuple("Pipeline with id: #{id} not found")
    rescue
      e -> {:error, e}
  end

  # Utility

  defp return_number({number, _}) when is_integer(number),
    do: return_ok_tuple(number)
  defp return_number(error), do: return_error_tuple(error)

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple(value, _),     do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
