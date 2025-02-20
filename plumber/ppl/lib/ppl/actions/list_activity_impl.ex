# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Ppl.Actions.ListActivityImpl do
  @moduledoc """
  Module which implements List Activity action
  """

  alias Util.Proto
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Ppls.Model.Triggerer
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.Actions.DescribeTopologyImpl

  import Ecto.Query
  import Ppl.Actions.ListImpl, only: [non_empty_value_or_default: 3]
  import Ppl.Ppls.Model.PplsQueries, only: [join_request_trace_and_ppl: 0]

  def list_activity(request) do
    with {:ok, params}     <- Proto.to_map(request),
         {:ok, page_size}  <- non_empty_value_or_default(params, :page_size, 30),
         {:ok, token}      <- non_empty_value_or_default(params, :page_token, nil),
         {:ok, org_id}     <- get_required_field(request, :organization_id),
         keyset_params     <- %{page_token: token, direction: params.direction,
                                page_size: page_size, order: params.order},
         {:ok, result}     <- list_activity_sql(org_id, keyset_params)
    do
      {:ok, result}
    else
      e = {:error, _msg} -> e
      error -> {:error, error}
    end
  end

    defp get_required_field(map, key) do
      case Map.get(map, key) do
        nil ->
          {:error, {:invalid_arg, "Request is missing required field: '#{key}'"}}

        "" ->
          {:error, {:invalid_arg, "Value of required field: '#{key}' is empty string."}}

        value -> {:ok, value}
      end
    end

    def list_activity_sql(org_id, keyset_params) do
      query =
        join_request_trace_and_ppl()
        |> where([p], fragment("(? = 'running' OR ? = 'queuing')", p.state, p.state))
        |> where([_p, _pt, pr, _q], fragment("?->>?", pr.request_args, "organization_id") == ^org_id)

      page =
        case keyset_params.order do
          :BY_CREATION_TIME_DESC ->
            query
            |> list_activity_by_inserted_at_desc(keyset_params)
            |> add_blocks_details()
          end

      {:ok, %{pipelines: page.entries, next_page_token: page.metadata.after || "",
              previous_page_token: page.metadata.before || ""}}
    end

    defp list_activity_by_inserted_at_desc(query, keyset_params) do
      query
      |> order_by([p], desc: p.inserted_at, desc: p.id)
      |> select_active_pipelines()
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

    defp add_blocks_details(page = %{entries: entries}) when entries == [], do: page
    defp add_blocks_details(page) do
      page.entries
      |> Enum.map(fn %{ppl_id: id} -> id end)
      |> PplBlocksQueries.all_blocks_from_pipelines()
      |> group_data(page.entries)
      |> reverse_map_put(:entries, page)
    end

    defp group_data({:ok, blocks}, pipelines) do
      pipelines
      |> Enum.reduce_while([], fn pipeline, acc ->
        pipeline.definition
        |> DescribeTopologyImpl.describe_topology()
        |> case do
          {:error, msg} -> {:halt, {:error, msg}}

          {:ok, %{blocks: topology_blocks}} ->
            pipeline = add_blocks_data(topology_blocks, blocks, pipeline)
            {:cont, acc ++ [pipeline]}
        end
      end)
    end
    defp group_data(error = {:error, _msg}, _pipelines), do: error

    defp add_blocks_data(topology_blocks, blocks, pipeline) do
      topology_blocks
      |> merge_with_block_details(blocks, pipeline)
      |> reverse_map_put(:blocks, pipeline)
      |> Map.put(:definition_file,
                  pipeline.working_directory <> "/" <> pipeline.yaml_file_name)
      |> Map.drop([:definition, :working_directory, :yaml_file_name])
    end

    defp merge_with_block_details(topology_blocks, all_blocks, ppl) do
      all_blocks
      |> Enum.filter(fn %{ppl_id: id} -> id == ppl.ppl_id end)
      |> Enum.map(fn block ->
        topology_blocks
        |> Enum.find(fn %{name: name} -> name == block.name end)
        |> Map.merge(block)
        |> format_jobs()
      end)
    end

    defp format_jobs(block = %{jobs: jobs, state: state}) do
      jobs
      |> Enum.with_index()
      |> Enum.map(fn {job_name, index} ->
        %{name: job_name,
          index: index,
          status: job_status(state)}
      end)
      |> reverse_map_put(:jobs, block)
    end

    defp job_status(state) when state in ["running", "done"], do: "scheduled"
    defp job_status(_state), do: "pending"

    defp reverse_map_put(value, key, map), do: Map.put(map, key, value)

    defp select_active_pipelines(query) do
      query
      |> select([p, pt, pr, q],
          %{
            id: p.id,
            inserted_at: p.inserted_at,
            organization_id: fragment("?->>?", pr.request_args, "organization_id"),
            project_id: p.project_id,
            wf_id: pr.wf_id,
            wf_number: p.wf_number,
            name: fragment("coalesce(nullif(?, ''), 'Pipeline')", p.name),
            ppl_id: p.ppl_id,
            hook_id: fragment("?->>?", pr.request_args, "hook_id"),
            switch_id: fragment("coalesce(?, '')", pr.switch_id),
            working_directory: fragment("coalesce(nullif(?, ''), '/')", fragment("?->>?", pr.request_args, "working_dir")),
            yaml_file_name: fragment("coalesce(nullif(?, ''), '.semaphore.yml')", fragment("?->>?", pr.request_args, "file_name")),
            priority: fragment("coalesce(?, 0)", p.priority),
            wf_triggered_by: fragment("?->>?", pr.request_args, "triggered_by"),
            requester_id: fragment("?->>?", pr.request_args, "requester_id"),
            partial_rerun_of: fragment("coalesce(?, '')", p.partial_rebuild_of),
            promotion_of:  fragment("coalesce(?, '')", p.extension_of),
            promoter_id: fragment("coalesce(?, '')", fragment("?->>?", pr.request_args, "promoter_id")),
            auto_promoted: fragment("case ? when 'true' then true else false end", fragment("?->>?", pr.request_args, "auto_promoted")),
            git_ref: fragment("?->>?", pr.request_args, "label"),
            git_ref_type: fragment("coalesce(?, '')", fragment("?->>?", pr.source_args, "git_ref_type")),
            commit_sha: p.commit_sha,
            commit_message: fragment("coalesce(?, '')", fragment("?->>?", pr.source_args, "commit_message")),
            commiter_username: fragment("coalesce(?, '')", fragment("?->>?", pr.source_args, "repo_host_username")),
            commiter_avatar_url: fragment("coalesce(?, '')", fragment("?->>?", pr.source_args, "repo_host_avatar_url")),
            branch_id: fragment("?->>?", pr.request_args, "branch_id"),
            state: p.state,
            created_at: pt.created_at,
            pending_at: pt.pending_at,
            queuing_at: pt.queuing_at,
            running_at: pt.running_at,
            definition: pr.definition,
            queue:  %{
              queue_id: fragment("coalesce(?::text, '')", q.queue_id),
              name: fragment("coalesce(?, '')", q.name),
              type: fragment("case ? when true then 'user_generated' else 'implicit' end", q.user_generated),
              scope: fragment("coalesce(?, '')", q.scope),
              project_id: fragment("coalesce(?, '')", q.project_id),
              organization_id: fragment("coalesce(?, '')", q.organization_id),
            },
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
  end
