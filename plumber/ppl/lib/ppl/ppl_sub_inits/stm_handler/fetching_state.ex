defmodule Ppl.PplSubInits.STMHandler.FetchingState do
  @moduledoc """
  Fetch Yaml definition and decide wether to go to regular_in state or to start
  compilation task.
  """

  import Ecto.Query

  alias Ppl.PplSubInits.Model.PplSubInits
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplRequests.Model.{PplRequests, PplRequestsQueries}
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplSubInits.STMHandler.Common
  alias Ppl.PplSubInits.STMHandler.Compilation
  alias Ppl.TaskClient
  alias Block.CodeRepo
  alias Ppl.EctoRepo, as: Repo

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_sub_init_fetching_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.PplSubInits.Model.PplSubInits,
    observed_state: "fetching",
    allowed_states: ~w(regular_init compilation done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_sub_init_fetching_ct),
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
    with {:ok, ppl_req}          <- PplRequestsQueries.get_by_id(psi.ppl_id),
         {:ok, yaml, definition} <- acquire_definition(psi, ppl_req),
         {:ok, pfcs}             <- acquire_pre_flight_checks(ppl_req),
         {:ok, settings}         <- acquire_organization_settings(ppl_req),
         {:ok, next_state}       <- next_state(ppl_req, definition, pfcs),
         {:ok, exit_func}        <- transition_to_state(ppl_req, {yaml, pfcs, settings}, next_state) do
      {:ok, exit_func}
    else
      error -> handle_error(error)
    end
  end

  defp next_state(ppl_req, definition, pfcs) do
    ppl_req.request_args
    |> Map.get("service")
    |> case do
      "git" -> {:ok, "compilation"}
      _ -> Compilation.Decider.decide_on_compilation(definition, pfcs)
    end
  end

  defp acquire_definition(psi, ppl_req) do
    case psi.init_type do
      "regular" -> ppl_req.request_args |> Map.get("service") |> get_and_validate_definition(ppl_req)
      "rebuild" -> duplicate_initial_definition(ppl_req.id)
      error -> raise("Unexpected value for 'init_type': '#{inspect error}'")
    end
  end

  defp duplicate_initial_definition(ppl_id) do
    with {:ok, ppl}         <- PplsQueries.get_by_id(ppl_id),
         {:ok, orig_ppl_or} <- PplOriginsQueries.get_by_id(ppl.partial_rebuild_of),
         {:ok, definition}  <- DefinitionValidator.validate_yaml_string(orig_ppl_or.initial_definition)
    do
      {:ok, orig_ppl_or.initial_definition, definition}
    end
  end

  defp get_and_validate_definition("git", _), do: {:ok, "", nil}

  defp get_and_validate_definition(_, ppl_req) do
    with {:ok, yaml}       <- CodeRepo.get_file(ppl_req.request_args, ppl_req.wf_id),
         {:ok, definition} <- DefinitionValidator.validate_yaml_string(yaml),
    do: {:ok, yaml, definition}
  end

  defp save_initial_definition(ppl_id, initial_definition) do
    with {:ok, ppl_or} <- PplOriginsQueries.get_by_id(ppl_id),
    do: PplOriginsQueries.save_definition(ppl_or, initial_definition)
  end

  defp acquire_pre_flight_checks(_ppl_ewq = %{request_args: req_args}),
    do: Ppl.PFCClient.describe(req_args["organization_id"], req_args["project_id"])

  defp acquire_organization_settings(_ppl_req = %{request_args: req_args}) do
    case Ppl.Cache.OrganizationSettings.get(req_args["organization_id"], [
           "plan_machine_type",
           "plan_os_image",
           "custom_machine_type",
           "custom_os_image"
         ]) do
      {:ok, settings} -> {:ok, settings}
      {:error, reason} -> {:error, {:organization_settings, reason}}
    end
  end

  defp transition_to_state(ppl_req, {_yaml, pfcs, settings}, "compilation") do
      describe_project =
        Task.async(fn ->
          ppl_req.request_args
          |> Map.get("project_id")
          |> Compilation.ProjectClient.describe()
        end)

    start_compilation =
      Task.async(fn -> TaskClient.Compilation.start(ppl_req, pfcs, settings) end)

      with {:ok, compl_task_id} <- Task.await(start_compilation),
           {:ok, project}       <- Task.await(describe_project),
           {:ok, _ppl_req}      <- update_ppl_request(ppl_req, project, pfcs),
           {:ok, _ppl}          <- update_pipeline(ppl_req.id, compl_task_id),
      do: {:ok, fn _, _ -> {:ok, %{state: "compilation", compile_task_id: compl_task_id}} end}
  end

  defp transition_to_state(ppl_req, {yaml, _pfcs, _settings}, next_state) do
    with {:ok, _ppl_or} <- save_initial_definition(ppl_req.id, yaml),
    do: {:ok, fn _, _ -> {:ok, %{state: next_state}} end}
  end

  defp update_ppl_request(ppl_req, %{spec: %{artifact_store_id: art_id}}, :undefined) do
    with req_args <- ppl_req.request_args |> Map.put("artifact_store_id", art_id),
         params   <- %{request_args: req_args},
    do: ppl_req |> PplRequests.changeset_compilation(params) |> Repo.update()
  end

  defp update_ppl_request(ppl_req, %{spec: %{artifact_store_id: art_id}}, pfcs) do
    with req_args <- ppl_req.request_args |> Map.put("artifact_store_id", art_id),
         params   <- %{request_args: req_args, pre_flight_checks: pfcs},
    do: ppl_req |> PplRequests.changeset_compilation(params) |> Repo.update()
  end

  defp update_pipeline(ppl_id, compl_task_id) do
    with {:ok, ppl} <- PplsQueries.get_by_id(ppl_id),
         params     <- %{compile_task_id: compl_task_id},
    do: ppl |> Ppls.changeset(params) |> Repo.update()
  end

  defp handle_error({:error, {:malformed, msg}}) do
    desc = "Error: #{inspect(msg)}"
    {:ok, fn _, _ ->
      {:ok, %{state: "done", error_description: desc, result: "failed", result_reason: "malformed"}}
    end}
  end
  defp handle_error(e = {:error, _error}), do: {:ok, fn _, _ -> e end}
  defp handle_error(error), do: {:ok, fn _, _ -> {:error, error} end}

  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.Ppls.STMHandler.InitializingState.execute_now_with_predicate()

    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "regular_init"}}}) do
    import Ecto.Query

    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.PplSubInits.STMHandler.RegularInitState.execute_now_with_predicate()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
