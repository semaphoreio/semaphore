defmodule Ppl.Actions.ScheduleImpl do
  @moduledoc """
  Module which implements Schedule pipeline action
  """

  import Ecto.Query

  alias Ppl.PplSubInits.STMHandler.ConceivedState
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.Model.{PplsQueries, Ppls}
  alias LogTee, as: LT
  alias Ppl.PplSubInits.STMHandler.CreatedState
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.RequestReviser
  alias Ecto.Multi
  alias InternalApi.Plumber.ScheduleRequest.ServiceType
  alias Ppl.LatestWfs.Model.{LatestWfs, LatestWfsQueries}
  alias Looper.STM.Publisher
  alias Ppl.Ppls.STMHandler.Common
  alias Util.{ToTuple, Metrics}


  defp publish_retry_count(), do: Application.get_env(:ppl, :publish_retry_count)
  defp publish_timeout(), do: Application.get_env(:ppl, :publish_timeout)

  # Form schedule params

  def form_params(message_map = %{"service" => :LISTENER_PROXY}) do
    with {:ok, svc} <- int2string(message_map, "service") do
      message_map
      |> Map.put("service", svc)
      |> Map.put("branch_name", message_map["label"])
      |> Map.delete("label")
      |> Map.put("wf_id", UUID.uuid4())
      |> ToTuple.ok()
    end
  end

  def form_params(message_map) do
    with  {:ok, map} <- extract_values_into_self(message_map, "repo"),
          {:ok, map} <- add_wf_id(map),
          {:ok, trb} <- int2string(map, "triggered_by"),
          {:ok, svc} <- int2string(map, "service")
    do
       map |> Map.put("service", svc) |> Map.put("triggered_by", trb) |> ToTuple.ok()
    end
  end

  defp extract_values_into_self(map, key) when is_map(map), do:
    extract_values_into_self_(Map.get(map, key), map, key)
  defp extract_values_into_self(map, _key), do:
    "Expected map, got #{inspect map}" |> ToTuple.error()

  defp extract_values_into_self_(value, map, key) when is_map(value), do:
    map |> Map.merge(value) |> Map.drop([key]) |> ToTuple.ok()
  defp extract_values_into_self_(value, _map, key), do:
    "expected map for key '#{key}'', got '#{inspect value}'" |> ToTuple.error()

  defp add_wf_id(map) do
    map |> Map.put("wf_id", UUID.uuid4()) |> ToTuple.ok()
  end

  defp int2string(map, key), do:
    map |> Map.get(key) |> get_service_type_key() |> service_value_to_string()

  defp get_service_type_key(value) when is_atom(value), do: {:ok, value}
  defp get_service_type_key(value) do
    value |> ServiceType.key() |> ToTuple.ok()
  rescue e ->
    {:error, {:invalid_enum_value, value, e}}
  end

  defp service_value_to_string({:ok, atom}), do:
    atom |> Atom.to_string() |> String.downcase() |> ToTuple.ok()
  defp service_value_to_string(error), do: error

  # Schedule

  def schedule(ctx, top_level?, initial_request?, start_in_conceived?) do
    log_run_request(ctx)

    ctx
    |> prepare_request_multi(top_level?, initial_request?, start_in_conceived?)
    |> persist_request
    |> case do
      {:ok, %{ppl_req: ppl_req}} ->
        with {:ok, args} <- prepare_publisher_args(ppl_req.id),
             Wormhole.capture(Publisher, :publish, args, stacktrace: true,
               retry_count: publish_retry_count(), timeout_ms: publish_timeout()),

             predicate   <- fn query -> query |> where(ppl_id: ^ppl_req.id) end,
             :ok         <- execute_first_state_with_predicate(predicate, start_in_conceived?),
        do: response(ppl_req)
      # Idempotency -> return {:ok, ...}
      {:error, :ppl_req, {:request_token_exists, request_token}, _} ->
        with {:ok, ppl_req}
          <- PplRequestsQueries.get_by_request_token(request_token),
        do: response(ppl_req)
      error ->
          LT.error(error, "Run request failure")
    end
  end

  defp execute_first_state_with_predicate(predicate, true),
    do: ConceivedState.execute_now_with_predicate(predicate)

  defp execute_first_state_with_predicate(predicate, false),
    do: CreatedState.execute_now_with_predicate(predicate)

  defp prepare_publisher_args(ppl_id) do
    [
      _ids       = %{ppl_id: ppl_id},
      _state     = "initializing",
      _encode_cb = fn params -> Common.publisher_callback(params) end
    ] |> ToTuple.ok()
  end

  defp response(ppl_req) do
    %{ppl_id: ppl_req.id, wf_id: ppl_req.wf_id, response_status: %{code: 0}}
    |> ToTuple.ok()
  end

  @suppressed_attributes ~w(access_token client_secret)
  defp log_run_request(ctx) do
    ctx
    |> suppress_attributes(@suppressed_attributes)
    |> LT.info("Request: 'run")
  end

  defp suppress_attributes(ctx, attribute_list) do
    attribute_list
    |> Enum.reduce(ctx, fn key, map -> Map.delete(map, key) end)
    |> Map.put("suppressed_attributes", attribute_list)
  end

  def prepare_request_multi(ctx, top_level?, initial_request?, start_in_conceived?) do
    ctx = RequestReviser.revise(ctx)

    Multi.new()
    # insert pipeline request
    |> Multi.run(:ppl_req, fn _, _ ->
      Metrics.benchmark("Ppl.schedule_break_down", ["insert_request"], fn ->
        PplRequestsQueries.insert_request(ctx, top_level?, initial_request?, start_in_conceived?)
      end)
    end)
    # insert pipeline based on that request
    |> Multi.run(:ppl, fn _, %{ppl_req: ppl_req} ->
      Metrics.benchmark("Ppl.schedule_break_down", ["insert_pipeline"], fn ->
        PplsQueries.insert(ppl_req, "", start_in_conceived?)
      end)
    end)
    # update pipeline to include wf_number
    |> Multi.run(:wf_num, fn _, %{ppl_req: ppl_req, ppl: ppl} ->
      Metrics.benchmark("Ppl.schedule_break_down", ["set_wf_num"], fn ->
        set_workflow_number(ppl, ppl_req, start_in_conceived?)
      end)
    end)
    # insert pipeline sub init for this pipeline
    |> Multi.run(:ppl_sub_init, fn _, %{ppl_req: ppl_req} ->
      Metrics.benchmark("Ppl.schedule_break_down", ["insert_subinit"], fn ->
        PplSubInitsQueries.insert(ppl_req, "regular", start_in_conceived?)
      end)
    end)
    # save inital_request separately for easier debug
    |> Multi.run(:ppl_origins_request, fn _, %{ppl_req: ppl_req} ->
      Metrics.benchmark("Ppl.schedule_break_down", ["insert_origin"], fn ->
        PplOriginsQueries.insert(ppl_req.id, ctx)
      end)
    end)
    # create ppl trace for that pipeline
    |> Multi.run(:ppl_trace, fn _, %{ppl: ppl} ->
      Metrics.benchmark("Ppl.schedule_break_down", ["insert_trace"], fn ->
        PplTracesQueries.insert(ppl)
      end)
    end)
  end

  # promotions
  def set_workflow_number(ppl, req = %{request_args: %{"wf_number" => num}}, start_in_conceived?)
    when is_integer(num) and num > 0 do
      with service     <- Map.get(req.request_args, "service"),
           {:ok, _ppl} <- update_ppl(ppl, service, num, start_in_conceived?),
      do: {:ok, num}
  end
  # partial rebuilds
  def set_workflow_number(ppl = %{partial_rebuild_of: val}, ppl_req, start_in_conceived?)
    when is_binary(val) and val != "" do
      with {:ok, l_wf} <- calculate_wf_num(ppl, ppl_req),
           service     <- Map.get(ppl_req.request_args, "service"),
           {:ok, _ppl} <- update_ppl(ppl, service, l_wf.wf_number + 1, start_in_conceived?),
      do: {:ok, l_wf.wf_number + 1}
  end
  # regular schedule and wf_rebuild
  def set_workflow_number(ppl, ppl_req, start_in_conceived?) do
    with {:ok, l_wf} <- read_from_latest_wf_table(ppl, ppl_req),
         service     <- Map.get(ppl_req.request_args, "service"),
         {:ok, _ppl} <- update_ppl(ppl, service, l_wf.wf_number + 1, start_in_conceived?),
         {:ok, _}    <- LatestWfsQueries.insert_or_update(l_wf, ppl_req, l_wf.wf_number + 1),
    do: {:ok, l_wf.wf_number + 1}
  end

  defp read_from_latest_wf_table(ppl, ppl_req) do
    case LatestWfsQueries.lock_and_get(ppl) do
      {:ok, l_wf} ->  {:ok, l_wf}

      {:error, "LatestWfs for project" <> _rest} ->
        calculate_wf_num(ppl, ppl_req)

      error -> error
    end
  end

  defp calculate_wf_num(ppl, ppl_req) do
    with {:ok, wf_init_ppl} <- get_initial_wf_ppl(ppl_req, ppl),
         {:ok, prev_num}    <- PplsQueries.previous_wfs_number(wf_init_ppl),
    do: {:ok, %LatestWfs{wf_number: prev_num}}
  end

  defp get_initial_wf_ppl(%{initial_request: true, top_level: true}, ppl),
    do: {:ok, ppl}
  defp get_initial_wf_ppl(%{wf_id: wf_id}, _ppl),
    do: PplsQueries.get_initial_wf_ppl(wf_id)

  defp update_ppl(ppl, service, wf_num, start_in_conceived?) do
    with_repo_data? = !start_in_conceived?

    ppl
    |> Ppls.changeset(%{wf_number: wf_num}, service == "listener_proxy", with_repo_data?)
    |> Repo.update()
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  def persist_request(multi), do: multi |> Repo.transaction()
end
