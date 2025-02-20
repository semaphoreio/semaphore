defmodule Ppl.PplSubInits.STMHandler.CompilationState do
  @moduledoc """
  Check if compilation task is done and fetch YAML and compile log for further
  procesing.
  """

  import Ecto.Query

  alias Ppl.PplSubInits.STMHandler.Compilation.{AtifactsClient}
  alias Ppl.TaskClient
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplSubInits.Model.PplSubInits
  alias Ppl.PplSubInits.STMHandler.Common
  alias LogTee, as: LT

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_sub_init_compilation_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.PplSubInits.Model.PplSubInits,
    observed_state: "compilation",
    allowed_states: ~w(regular_init compilation stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_sub_init_compilation_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id]


  def initial_query(), do: PplSubInits

  def terminate_request_handler(psi, "stop") do
    case TaskClient.terminate(psi.compile_task_id) do
      {:ok, _response} ->
          {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end
  def terminate_request_handler(_psi, _), do: {:ok, :continue}

  def scheduling_handler(psi) do
    with {:ok, state, result} <- TaskClient.describe(psi.compile_task_id),
         {:ok, ppl_req}       <- PplRequestsQueries.get_by_id(psi.ppl_id),
         {:ok, exit_func}     <- transition_to_state(ppl_req, state, result)
    do
     {:ok, exit_func}
    else
     error  ->  handle_error(error)
    end
  end

  defp transition_to_state(ppl_req, "done", "failed") do
    with partial_path    <- "#{ppl_req.request_args["file_name"]}.logs",
         {art_id, wf_id} <- {ppl_req.request_args["artifact_store_id"], ppl_req.wf_id},
         {:ok, logs}     <- fetch_file(ppl_req, art_id, wf_id, partial_path),
         params          <- prepare_failing_params(ppl_req.request_args, logs)
    do
      {:ok, fn _, _ -> {:ok, params} end}
    else
      {:error, {:not_found, error}} ->
        LT.warn(error, "Failed to fetch compilation logs from artifacts for pipeline #{ppl_req.id}")
        {:ok, fn _, _ -> {:ok, prepare_failing_params(ppl_req.request_args, "")} end}

      error -> error
    end
  end

  defp transition_to_state(ppl_req = %{request_args: req_args}, "done", "passed") do
    with partial_path      <- "#{req_args["file_name"]}",
         {art_id, wf_id}   <- {req_args["artifact_store_id"], ppl_req.wf_id},
         {:ok, definition} <- fetch_file(ppl_req, art_id, wf_id, partial_path),
         {:ok, _ppl_or}    <- save_initial_definition(ppl_req.id, definition)
    do
      {:ok, fn _, _ -> {:ok, %{state: "regular_init"}} end}
    else
      {:error, {:not_found, error}} ->
        LT.warn(error, "Failed to fetch compiled yaml from artifacts for pipeline #{ppl_req.id}")
        {:ok, fn _, _ -> {:ok, prepare_failing_params(ppl_req.request_args, "")} end}

      error -> error
    end
  end

  defp transition_to_state(_ppl_req, "done", "stopped") do
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "stopped", result_reason: "user"}} end}
  end

  # If it is not "done" we treat task as "running"
  defp transition_to_state(_ppl_req, _state, _result),
    do: {:ok, fn _, _ -> {:ok, %{state: "compilation"}} end}

  defp fetch_file(ppl_req, art_id, wf_id, partial_path) do
    path = "compilation/#{ppl_req.id}-" <> partial_path

    case AtifactsClient.acquire_file(art_id, wf_id, path) do
      {:ok, file} -> {:ok, file}

      {:error, {:not_found, _}} ->
        old_path_format = "compilation/" <> partial_path
        AtifactsClient.acquire_file(art_id, wf_id, old_path_format)

      error -> error
    end
  end

  defp prepare_failing_params(req_args, "") do
    yml_file = "#{req_args["working_dir"]}/#{req_args["file_name"]}"

    description =
      ~s({"message":"Initialization step failed, see logs for more details.",)
      <> ~s("location":{"file":"#{yml_file}","path":[]},)
      <> ~s("type":"ErrorInitializationFailed"}\n)

    %{state: "done", result_reason: "stuck",
      result: "failed", error_description: description}
  end
  defp prepare_failing_params(_req_args, logs) do
    %{state: "done", result_reason: "malformed",
      result: "failed", error_description: logs}
  end

  defp save_initial_definition(ppl_id, initial_definition) do
    with {:ok, ppl_or} <- PplOriginsQueries.get_by_id(ppl_id),
    do: PplOriginsQueries.save_definition(ppl_or, initial_definition)
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
