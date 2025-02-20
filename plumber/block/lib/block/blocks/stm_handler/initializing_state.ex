defmodule Block.Blocks.STMHandler.InitializingState do
  @moduledoc """
  Handle block's definition refinment
  """

  @entry_metric_name "Ppl.ppl_task_init_overhead"

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:block, :blk_initializing_sp),
    repo: Block.EctoRepo,
    schema: Block.Blocks.Model.Blocks,
    observed_state: "initializing",
    allowed_states: ~w(running done),
    cooling_time_sec: Util.Config.get_cooling_time(:block, :blk_initializing_ct),
    columns_to_log: [:state, :recovery_count, :block_id]

  require Block.Ctx

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.{Blocks, BlocksQueries}
  alias Block.Tasks.Model.TasksQueries
  alias Block.BlockSubppls.Model.BlockSubpplsQueries
  alias Block.CommandsFileReader.DefinitionRefiner
  alias Block.Blocks.STMHandler.Common
  alias Ecto.Multi
  alias Block.Ctx
  alias Block.EctoRepo, as: Repo
  alias Util.{ToTuple, Metrics}

  def initial_query(), do: Blocks

  def terminate_request_handler(blk, result) when result in ["cancel", "stop"] do
    reason = determin_reason(blk)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_pple, _), do: {:ok, :continue}

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"

  def scheduling_handler(blk) do
    with {:ok, blk_req}    <- BlockRequestsQueries.get_by_id(blk.block_id),
         {:ok, definition} <- JobMatrix.Handler.handle_block(blk_req.definition),
         {:ok, definition} <- DefinitionRefiner.cmd_files_to_commands(definition, blk_req.request_args),
         build             <- Map.get(definition, "build", %{}),
         {:ok, build}      <- resolve_fail_fast_setting(build, blk_req.request_args, blk_req.source_args),
         rsp = {:ok, _b_r} <- BlockRequestsQueries.insert_build(blk_req, %{build: build})
    do handle_refinement(rsp)
    else
      e  -> handle_refinement(e)
    end
  end

  defp resolve_fail_fast_setting(build, req_args, src_args) do
    with ref_type         <- Map.get(src_args, "git_ref_type", ""),
         ppl_ff           <- Map.get(req_args, "ppl_fail_fast", "none"),
         ppl_args         <- make_ppl_args(src_args, req_args),
         {:ok, fail_fast} <- decide_on_fail_fast(build, ppl_args, ref_type, ppl_ff)
    do
      build |> Map.put("fail_fast", fail_fast) |> ToTuple.ok()
    end
  end

  defp make_ppl_args(src_args, req_args)
    when is_map(src_args) and is_map(req_args), do: Map.merge(req_args, src_args)
  defp make_ppl_args(_src_args, req_args) when is_map(req_args), do: req_args
  defp make_ppl_args(_src_args, _req_args), do: %{}

  defp decide_on_fail_fast(%{"fail_fast" => ff_settings}, ppl_args, ref_type, ppl_ff) do
    with {:ok, params}  <- when_params(ppl_args, ppl_args["label"], ref_type),
         {:ok, stop?}   <- ff_do_stop?(ff_settings, params),
         {:ok, cancel?} <- ff_do_cancel?(ff_settings, params)
    do
      make_decision(stop?, cancel?, ppl_ff)
    end
  end
  defp decide_on_fail_fast(_definition, _ppl_args, _ref_type, ppl_ff), do: {:ok, ppl_ff}

  defp when_params(ppl_args, label, ref_type) when ref_type in ["branch", "tag", "pr"] do
    ppl_args
    |> default_when_params()
    |> Map.put(key(ref_type), label)
    |> add_pr_base?(ppl_args, ref_type)
    |> use_pr_head_commit?(ppl_args, ref_type)
    |> ToTuple.ok()
  end
  defp when_params(ppl_args, _label, _ref_type),
    do: default_when_params(ppl_args) |> ToTuple.ok()

  defp key("pr"), do: "pull_request"
  defp key(ref_type), do: ref_type

  defp default_when_params(ppl_args) do
    ppl_args
    |> Map.take(["working_dir", "commit_sha", "project_id", "commit_range"])
    |> Map.put("yml_file_name", ppl_args["file_name"] || "")
    |> Map.merge(%{"branch" => "", "tag" => "", "pull_request" => ""})
  end

  defp add_pr_base?(map, ppl_args, "pr"),
    do: map |> Map.put("pr_base", ppl_args["branch_name"] || "")
  defp add_pr_base?(map, _ppl_args, _ref_type),
    do:  map |> Map.put("pr_base", "")

  defp use_pr_head_commit?(map, ppl_args, "pr"),
    do: map |> Map.put("commit_sha", ppl_args["pr_sha"] || "")
  defp use_pr_head_commit?(map, _ppl_args, _ref_type), do: map

  defp make_decision(true, _cancel?, _ppl_ff), do: {:ok, "stop"}
  defp make_decision(_stop?, true, _ppl_ff), do: {:ok, "cancel"}
  defp make_decision(_stop?, _cancel?, ppl_ff), do: {:ok, ppl_ff}

  defp ff_do_stop?(%{"stop" => %{"when" => condition}}, params)
    when is_binary(condition) do
      When.evaluate(condition, params)
  end
  defp ff_do_stop?(%{"stop" => %{"when" => bool}}, _params)
    when is_boolean(bool), do: {:ok, bool}
  defp ff_do_stop?(_ff_setting, _params), do: {:ok, false}

  defp ff_do_cancel?(%{"cancel" => %{"when" => condition}}, params)
    when is_binary(condition) do
      When.evaluate(condition, params)
  end
  defp ff_do_cancel?(%{"cancel" => %{"when" => bool}}, _params)
    when is_boolean(bool), do: {:ok, bool}
  defp ff_do_cancel?(_ff_setting, _params), do: {:ok, false}

  defp handle_refinement({:error, {:malformed, msg}}) do
    error_desc = "Error: #{inspect msg}"
    {:ok, fn _, _ -> {:ok, %{error_description: error_desc, state: "done",
                          result: "failed", result_reason: "malformed"}} end}
  end
  defp handle_refinement({:error, msg}) do
    error = "Error: #{inspect msg}"
    {:ok, fn _, _ -> {:error, %{description: error}} end}
  end
  defp handle_refinement({:ok, blk_req}) do
    Multi.new
    |> create_task(blk_req, blk_req.has_build?)
    |> create_block_subppls(blk_req)
    |> Repo.transaction
    |> all_ok?()
  end

  defp create_task(multi, _blk_req, false), do: multi
  defp create_task(multi, blk_req, _) do
    TasksQueries.multi_insert(multi, blk_req)
  end

  defp create_block_subppls(multi, blk_req) do
    blk_req
    |> get_includes()
    |> Enum.with_index()
    |> Enum.reduce(multi, fn(subppl_params, multi) ->
                             BlockSubpplsQueries.multi_insert(multi, blk_req, subppl_params)
                           end)
  end

  defp get_includes(blk_req), do: get_in(blk_req, [Access.key(:definition), "includes"]) || []


  def all_ok?({:ok, multi_result}) do
    multi_result
    |> Enum.each(fn {_key, value} -> Ctx.event({:ok, value}, "created") end)
    {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
  end

  def all_ok?({:error, failed_operation, failed_value, _}) do
    message =  "Error while transitioning to 'running', "
                <> "failed event: #{failed_operation}, "
                <> "failed value: #{inspect failed_value}"
    {:ok, fn _, _ -> {:error, %{description: message}} end}
  end


  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_ppl_block_when_done(data)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "running"}}}) do
    import Ecto.Query

    block_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:block_id)

    fn query -> query |> where(block_id: ^block_id) end
    |> Block.Tasks.STMHandler.PendingState.execute_now_with_predicate()

    with {:ok, block} <- BlocksQueries.get_by_id(block_id),
         {:ok, task}  <- TasksQueries.get_by_id(block_id),
         diff <- NaiveDateTime.diff(task.inserted_at, block.inserted_at, :millisecond)
    do
       {@entry_metric_name, [Metrics.dot2dash(__MODULE__)]}
       |> Watchman.submit(diff, :timing)
    end
  end
  def epilogue_handler(_exit_state), do: :nothing
end
