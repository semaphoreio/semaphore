defmodule Ppl.PplSubInits.STMHandler.RegularInitState do
  @moduledoc """
  Handles acquireing, validating and revising pipeline definition and creating
  all other related structures and entities necessary for pipeline execution.
  """

  require Ppl.Ctx

  import Ecto.Query

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplSubInits.Model.PplSubInits
  alias Ppl.PplSubInits.STMHandler.Common
  alias Ppl.{DefinitionReviser, PplsReviser, Ctx}
  alias Ppl.PplBlocks.Model.{PplBlocksQueries, PplBlockConectionsQueries}
  alias Ppl.AfterPplTasks.Model.AfterPplTasksQueries
  alias Ppl.PplBlocks.STMHandler.InitializingState, as: PplBlocksInitializingState
  alias Ecto.Multi
  alias Ppl.EctoRepo, as: Repo
  alias Util.ToTuple

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_sub_init_regular_init_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.PplSubInits.Model.PplSubInits,
    observed_state: "regular_init",
    allowed_states: ~w(done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_sub_init_regular_init_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id]

  def initial_query(), do: PplSubInits

  def terminate_request_handler(psi, result) when result in ["cancel", "stop"] do
    reason = determin_reason(psi)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_psi, _), do: {:ok, :continue}

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"

  def scheduling_handler(psi) do
    with {:ok, ppl_req}     <- PplRequestsQueries.get_by_id(psi.ppl_id),
         {:ok, definition}  <- acquire_definition(psi),
         {:ok, def_revison} <- DefinitionReviser.revise_definition(definition, ppl_req),
         prev_ids           <- ppl_req.prev_ppl_artefact_ids ++ [ppl_req.ppl_artefact_id],
         {:ok, ref_args}    <- form_ref_args(ppl_req),
         {:ok, switch_id}   <- GoferClient.create_switch(def_revison, psi.ppl_id, prev_ids, ref_args),
         {:ok, ppl_req}     <- PplRequestsQueries.insert_definition(ppl_req, def_revison, switch_id),
         with_after_task?   <- with_after_task?(ppl_req),
         {:ok, _ppl}        <- PplsReviser.update_ppl(ppl_req, def_revison, ppl_req.source_args, with_after_task?),
         duplicate?         <- psi.init_type == "rebuild"
    do
       handle_validate(:ok, ppl_req, duplicate?)
    else
      e  ->  handle_validate(e)
    end
  end

  defp with_after_task?(ppl_req) do
    AfterPplTasksQueries.present?(ppl_req)
    |> case do
      true ->
        AfterPplTasksQueries.insert(ppl_req)
        |> case do
          {:ok, _} -> true
          _ -> false
        end
      false -> false
    end
  end

  defp form_ref_args(%{request_args: req_args, source_args: src_args}) do
    %{
      branch_name: req_args |> Map.get("branch_name", ""),
      label: req_args |> Map.get("label", ""),
      git_ref_type: src_args |> Map.get("git_ref_type", ""),
      project_id: req_args |> Map.get("project_id", ""),
      commit_sha: req_args |> Map.get("commit_sha", ""),
      working_dir: req_args |> Map.get("working_dir", ""),
      commit_range: src_args |> Map.get("commit_range", ""),
      yml_file_name: req_args |> Map.get("file_name", ""),
    }
    |> add_pr_base?(src_args, Map.get(src_args, "git_ref_type"))
    |> add_pr_sha?(src_args, Map.get(src_args, "git_ref_type"))
    |> ToTuple.ok()
  end

  defp add_pr_base?(map, src_args, "pr"),
    do: map |> Map.put(:pr_base, src_args["branch_name"] || "")
  defp add_pr_base?(map, _src_args, _ref_type),
    do:  map |> Map.put(:pr_base, "")

  defp add_pr_sha?(map, src_args, "pr"),
    do: map |> Map.put(:pr_sha, src_args["pr_sha"] || "")
  defp add_pr_sha?(map, _src_args, _ref_type),
    do:  map |> Map.put(:pr_sha, "")

  defp acquire_definition(psi) do
    with {:ok, ppl_or}     <- PplOriginsQueries.get_by_id(psi.ppl_id),
         yaml              <- ppl_or.initial_definition,
         do: DefinitionValidator.validate_yaml_string(yaml)
  end

  defp create_ppl_blocks(ppl_req, duplicate) do
    Multi.new
    |> PplBlocksQueries.multi_insert(ppl_req, duplicate)
    |> PplBlockConectionsQueries.multi_insert(ppl_req)
    |> Repo.transaction
    |> all_ok?()
  end

  def all_ok?({:ok, multi_result}) do
    multi_result
    |> Enum.map(fn {_key, value} ->
      Ctx.event({:ok, value}, "created")
      value
    end)
    |> ToTuple.ok()
  end

  def all_ok?({:error, failed_operation, failed_value, _}) do
    {:error, "Error while creating pipeline blocks, failed event: #{failed_operation}, "
              <> "failed value: #{inspect failed_value}"}
  end

  defp handle_validate(:ok, ppl_req, duplicate?) do
    {:ok, fn _, _ ->
      {:ok, _} = create_ppl_blocks(ppl_req, duplicate?)
      {:ok, %{state: "done", result: "passed"}}
    end}
  end

  defp handle_validate({:error, {:malformed, msg}}) do
    desc = "Error: #{inspect(msg)}"
    {:ok, fn _, _ ->
      {:ok, %{state: "done", error_description: desc, result: "failed", result_reason: "malformed"}}
    end}
  end

  defp handle_validate(error), do: {:ok, fn _, _ -> {:error, error} end}

#######################

  def epilogue_handler({:ok, data}) do
    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.Ppls.STMHandler.InitializingState.execute_now_with_predicate()

    case PplRequestsQueries.get_by_id(data.exit_transition.ppl_id) do
     {:ok, ppl_req} ->
       0..(ppl_req.block_count - 1)
       |> Enum.each(fn index ->
         trigger_block_looper(ppl_id, index)
       end)
      _ -> :nothing
    end

    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing

  defp trigger_block_looper(ppl_id, index) do
    query_fun =
      fn query ->
        query |> where(ppl_id: ^ppl_id) |> where(block_index: ^index)
      end

    query_fun |> PplBlocksInitializingState.execute_now_with_predicate()
  end
end
