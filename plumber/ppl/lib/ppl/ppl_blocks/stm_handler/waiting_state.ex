defmodule Ppl.PplBlocks.STMHandler.WaitingState do
  @moduledoc """
  Handles running of pipeline's blocks
  """

  @entry_metric_name "Ppl.block_init_overhead"

  @partition_copied_metric "Ppl.job_copy_partition.copied_count"
  @partition_rerun_metric "Ppl.job_copy_partition.rerun_count"
  @partition_mismatch_metric "Ppl.job_copy_partition.mismatch"
  @partition_describe_error_metric "Ppl.job_copy_partition.describe_error"
  @partition_provider_error_metric "Ppl.job_copy_partition.provider_error"

  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries, WaitingStateScheduling}
  alias Ppl.PplBlocks.STMHandler.Common
  alias LogTee, as: LT
  alias Util.{ToTuple, Metrics}

  use Looper.STM,
    id: __MODULE__,
    period_ms: 1_000,
    repo: Ppl.EctoRepo,
    schema: Ppl.PplBlocks.Model.PplBlocks,
    observed_state: "waiting",
    allowed_states: ~w(waiting running done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_blk_waiting_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id, :block_index],
    publisher_cb: fn params -> Common.publisher_callback(params) end

  def initial_query(), do: PplBlocks

#######################

  def enter_scheduling(_) do
    with {:ok, [{old, new}]} <- WaitingStateScheduling.get_ready_block(),
         true                <- ppl_block_in_waiting_state(old)
    do
      {:ok, {old, new}}
    else
      {:ok, []}   -> {:ok, {nil, nil}}
      :skip_scheduling -> {:ok, {nil, nil}}
      err         -> err |> LT.error("Error in waiting scheduling")
    end
  end

  defp ppl_block_in_waiting_state(%{state: "waiting"}), do: true
  defp ppl_block_in_waiting_state(ppl) do
    ppl |> LT.info("Race in waiting STM, selected ppl_block was already processed")
    execute_now()
    :skip_scheduling
  end

#######################

  def terminate_request_handler(ppl_blk, result) when result in ["cancel", "stop"] do
    reason = Common.determin_reason(ppl_blk)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_ppl_blk, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl_blk) do
    LT.info(ppl_blk.ppl_id, "PplBlocks WaitingState STM is scheduling block #{ppl_blk.block_index} from pipeline")
    case PplBlocksQueries.should_do_fast_failing?(ppl_blk) do
      {:ok, false} ->
        Metrics.benchmark("Ppl.ppl_blk.waiting_STM", "scheduling",  fn ->
         scheduling_handler_(ppl_blk)
        end)
      {:ok, ff_strategy} ->
         Common.do_fast_failing(ppl_blk, ff_strategy, "waiting")
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  def scheduling_handler_(ppl_blk) do
    ppl_blk = ppl_blk |> preload_deps()
    ppl_blk
    |> run_if_dependencies_passed()
    |> handle_run(ppl_blk)
  end

  defp preload_deps(ppl_blk) do
    Metrics.benchmark("Ppl.ppl_blk.waiting_STM", "preload_deps",  fn ->
     PplBlocksQueries.preload_dependencies(ppl_blk)
    end)
  end

  defp run_if_dependencies_passed(ppl_blk)do
    ppl_blk.connections
    |> Enum.find(:all_passed,
      fn connection -> connection.dependency_pipeline_block.result != "passed"
    end)
    |> cancel_skip_or_run_block(ppl_blk)
  end

  defp cancel_skip_or_run_block(:all_passed, ppl_blk), do: skip_or_run_block(ppl_blk)
  defp cancel_skip_or_run_block(_, _), do: cancel_block()

  def cancel_block(), do: {:ok, "done", {"canceled", "fast_failing"}}

  defp skip_or_run_block(ppl_blk) do
    with {:ok, ppl_req}      <- PplRequestsQueries.get_by_id(ppl_blk.ppl_id),
         label               <- ppl_req.request_args |> Map.get("label", ""),
         ppl_args            <- make_ppl_args(ppl_req.source_args, ppl_req.request_args),
         {:ok, block_def}    <- get_block_definition(ppl_req, ppl_blk.block_index),
         {:ok, skip?}        <- skip_block?(block_def, label, ppl_args),
         {:ok, run?}         <- run_block?(block_def, label, ppl_args),
         {:ok, skip_or_run?} <- decide(skip?, run?)
    do
      run_block(ppl_req, ppl_blk, block_def, skip_or_run?)
    else
      error -> error
    end
  end

  defp make_ppl_args(src_args, req_args)
    when is_map(src_args) and is_map(req_args), do: Map.merge(req_args, src_args)
  defp make_ppl_args(_src_args, req_args) when is_map(req_args), do: req_args
  defp make_ppl_args(_src_args, _req_args), do: %{}

  defp run_block(_ppl_req, _ppl_blk, _block_def, :skip),
    do: {:ok, "done", {"passed", "skipped"}}

  defp run_block(ppl_req, ppl_blk, block_def, :run) do
    Metrics.benchmark("Ppl.ppl_blk.waiting_STM", "run_block",  fn ->
      schedule_block(ppl_req, ppl_blk, block_def)
    end)
  end

  # only skip in yml definition
  defp decide(true, nil), do: {:ok, :skip}
  defp decide(false, nil), do: {:ok, :run}
  # only run in yml definition
  defp decide(nil, true), do: {:ok, :run}
  defp decide(nil, false), do: {:ok, :skip}
  # if neither is  defined, block is run by defult
  defp decide(nil, nil), do: {:ok, :run}
  # yml schema should prevent the case where both are defined, and in case it
  # still happens it is better to skip block so it can not do anything irreparable
  defp decide(_skip?, _run?), do: {:ok, :skip}

  def skip_block?(%{"filters" => filters}, branch, _ppl_args) do
    filters
    |> Enum.reduce_while({:ok, false}, fn filter, _default_resp ->
       if filter_match(filter, branch) do
         {:halt, {:ok, filter["action"] != "execute"}}
       else
         {:cont, {:ok, false}}
       end
     end)
  end
  def skip_block?(%{"skip" => %{"when" => when_expr}}, label, ppl_args)
    when is_binary(when_expr) do
      with ref_type      <- ppl_args |> Map.get("git_ref_type", ""),
           {:ok, params} <- when_params(ppl_args, label, ref_type),
           do: When.evaluate(when_expr, params)
  end
  def skip_block?(%{"skip" => %{"when" => bool_value}}, _branch, _ppl_args)
    when is_boolean(bool_value), do: {:ok, bool_value}
  def skip_block?(_block_def, _ppl_req, _ppl_args), do: {:ok, nil}

  def run_block?(%{"run" => %{"when" => when_expr}}, label, ppl_args)
    when is_binary(when_expr) do
      with ref_type      <- ppl_args |> Map.get("git_ref_type", ""),
           {:ok, params} <- when_params(ppl_args, label, ref_type),
           do: When.evaluate(when_expr, params)
  end
  def run_block?(%{"run" => %{"when" => bool_value}}, _branch, _ppl_args)
    when is_boolean(bool_value), do: {:ok, bool_value}
  def run_block?(_block_def, _ppl_req, _ppl_args), do: {:ok, nil}

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

  defp filter_match(%{"label" => value}, branch) when value == branch, do: true
  defp filter_match(%{"label_pattern" => pattern}, branch),
    do: Regex.match?(~r/#{pattern}/, branch)
  defp filter_match(_filter, _branch), do: false

  def schedule_block(ppl_req, ppl_blk, block_def) do
    with {:ok, ppl}           <- PplsQueries.get_by_id(ppl_req.id),
         {:ok, block_request} <- form_request(ppl_req, ppl_blk, block_def, ppl),
         {:ok, block_id}      <- Block.schedule(block_request),
    do: {:ok, "running", block_id}
  end

  defp get_block_definition(ppl_req, block_index) do
    block_definition = Enum.at(Map.get(ppl_req.definition, "blocks"), block_index)
    {:ok, block_definition}
  end

  defp form_request(ppl_req, ppl_blk, definition, ppl) do
    %{ppl_id: ppl_req.id, pple_block_index: ppl_blk.block_index,
      hook_id: Map.get(ppl_req.request_args, "hook_id"),
      request_args: ppl_req.request_args, definition: definition,
      source_args: ppl_req.source_args
    }
    |> Map.put(:version, ppl_req.definition["version"])
    |> put_in([:request_args, "ppl_fail_fast"], ppl.fast_failing)
    |> put_in([:request_args, "wf_id"], ppl_req.wf_id)
    |> put_in([:request_args, "ppl_priority"], ppl.priority)
    |> maybe_put_job_copy_partition(ppl_req, ppl_blk, ppl, definition)
    |> ToTuple.ok()
  end

  defp maybe_put_job_copy_partition(request, ppl_req, ppl_blk = %{duplicate: true}, ppl, definition) do
    org_id = Map.get(ppl_req.request_args, "organization_id")

    with true             <- partial_rerun_wanted?(ppl_req, definition),
         true             <- job_copy_partition_enabled?(org_id),
         {:ok, partition} <- compute_job_copy_partition(ppl, ppl_blk, definition)
    do
      request |> put_in([:request_args, "job_copy_partition"], partition)
    else
      _ -> request
    end
  rescue
    error ->
      Watchman.increment(@partition_mismatch_metric)
      error |> LT.warn("job_copy_partition: unexpected error, rescheduling whole block")
      request
  end
  defp maybe_put_job_copy_partition(request, _ppl_req, _ppl_blk, _ppl, _definition), do: request

  defp partial_rerun_wanted?(ppl_req, block_def) do
    setting =
      Map.get(block_def, "partial_rerun") ||
        Map.get(ppl_req.definition || %{}, "partial_rerun")

    setting != "block"
  end

  defp job_copy_partition_enabled?(org_id) do
    Ppl.Features.job_level_partial_rerun_enabled?(org_id)
  rescue
    error ->
      Watchman.increment(@partition_provider_error_metric)
      error |> LT.warn("job_copy_partition: feature check failed, rescheduling whole block")
      false
  end

  defp compute_job_copy_partition(ppl, ppl_blk, definition) do
    with {:ok, orig_ppl_blk} <- get_original_block(ppl, ppl_blk),
         {:ok, orig_jobs}    <- describe_original_jobs(orig_ppl_blk.block_id),
         :ok                 <- check_partition_alignment(orig_jobs, definition)
    do
      {copied, rerun} = orig_jobs |> Enum.split_with(&copy_original_job?/1)

      markers = copied |> Enum.into(%{}, &marker_pair/1)

      rerun_markers =
        rerun
        |> Enum.filter(fn job ->
          is_map(job) and is_binary(Map.get(job, :job_id)) and not is_nil(Map.get(job, :index))
        end)
        |> Enum.into(%{}, &marker_pair/1)

      Watchman.submit(@partition_copied_metric, map_size(markers))
      Watchman.submit(@partition_rerun_metric, length(orig_jobs) - map_size(markers))

      if map_size(markers) > 0 do
        {:ok, %{"original_block_id" => orig_ppl_blk.block_id, "jobs" => markers,
                "rerun_jobs" => rerun_markers}}
      else
        {:error, :no_copyable_jobs}
      end
    end
  end

  defp get_original_block(%{partial_rebuild_of: orig_ppl_id}, ppl_blk)
    when is_binary(orig_ppl_id) and orig_ppl_id != "" do
    case PplBlocksQueries.get_by_id_and_index(orig_ppl_id, ppl_blk.block_index) do
      {:ok, orig_ppl_blk = %{block_id: block_id}} when is_binary(block_id) ->
        {:ok, orig_ppl_blk}

      error ->
        Watchman.increment(@partition_mismatch_metric)
        error |> LT.warn("job_copy_partition: original block not resolvable, rescheduling whole block")
        {:error, :original_block_not_found}
    end
  end
  defp get_original_block(_ppl, _ppl_blk) do
    Watchman.increment(@partition_mismatch_metric)
    {:error, :original_pipeline_not_found}
  end

  defp describe_original_jobs(orig_block_id) do
    Watchman.benchmark("Ppl.job_copy_partition.describe.duration", fn ->
      case Block.describe(orig_block_id) do
        {:ok, description} ->
          {:ok, Map.get(description, :jobs) || []}

        error ->
          Watchman.increment(@partition_describe_error_metric)
          error |> LT.warn("job_copy_partition: original block describe failed, rescheduling whole block")
          {:error, :describe_failed}
      end
    end)
  end

  defp check_partition_alignment(orig_jobs, definition) do
    with {:ok, expanded} <- JobMatrix.Handler.handle_block(definition),
         new_jobs        <- get_in(expanded, ["build", "jobs"]) || [],
         true            <- length(new_jobs) > 0,
         orig_indexes    <- orig_jobs |> Enum.map(&Map.get(&1, :index)) |> Enum.sort(),
         true            <- orig_indexes == Enum.to_list(0..(length(new_jobs) - 1))
    do
      :ok
    else
      _ ->
        Watchman.increment(@partition_mismatch_metric)
        {:error, :partition_mismatch}
    end
  end

  defp copy_original_job?(job) when is_map(job) do
    Map.get(job, :status) == "FINISHED" and Map.get(job, :result) == "PASSED" and
      is_binary(Map.get(job, :job_id)) and not is_nil(Map.get(job, :index))
  end
  defp copy_original_job?(_job), do: false

  defp marker_pair(job), do: {"#{Map.get(job, :index)}", Map.get(job, :job_id)}

  defp entry_metrics?([], ppl_id, block_id) do
    with {:ok, trace} <- PplTracesQueries.get_by_id(ppl_id),
         {:ok, block} <- Block.status(block_id),
         diff <- DateTime.diff(trace.running_at, block.inserted_at, :millisecond)
    do
       {@entry_metric_name, [Metrics.dot2dash(__MODULE__)]}
       |> Watchman.submit(diff, :timing)
    end
  end
  defp entry_metrics?(_connections, _ppl_id, _block_id), do: :continue

  defp set_time_limit(ppl_blk = %{exec_time_limit_min: limit})
  when is_integer(limit) and limit > 0 do
    TimeLimitsQueries.set_time_limit(ppl_blk, "ppl_block")
  end
  defp set_time_limit(_ppl_blk), do: {:ok, :continue}

  defp handle_run({:ok, "running", block_id}, ppl_blk) do
    with _result    <- entry_metrics?(ppl_blk.connections, ppl_blk.ppl_id, block_id),
         {:ok, _tl} <- set_time_limit(ppl_blk)
    do
      LT.info(block_id, "Block #{ppl_blk.block_index} of pipeline with id: "
                         <> "#{ppl_blk.ppl_id} scheduled in block service with id: ")
      {:ok, fn _, _ -> {:ok, %{state: "running", block_id: block_id}} end}
    else
      error ->   {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  defp handle_run({:ok, "done", {result, reason}}, _ppl_blk) do
    {:ok, fn _, _ -> {:ok, %{state: "done", result: result, result_reason: reason}} end}
  end

  defp handle_run({:error, {:malformed, msg}}, _ppl_blk) do
    {:ok, fn _, _ ->
      {:ok, %{state: "done", error_description: msg, result: "failed",
              result_reason: "malformed"}}
    end}
  end

  defp handle_run({:error, msg}, _ppl_blk) do
    error_desc = "#{inspect msg}" |> LT.warn("PplBlocks WaitingState STM error")
    {:ok, fn _, _ -> {:error, %{error_description: error_desc}} end}
  end

#######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_ppl_when_done(data)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
