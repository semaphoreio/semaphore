defmodule Ppl.Grpc.Server do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Plumber.PipelineService.Service

  alias Ppl.Actions
  alias Ppl.Actions.ListActivityImpl
  alias Util.{Metrics, ToTuple, Proto}
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.Ppls.Model.Triggerer, as: TriggererModel
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.DeleteRequests.Model.DeleteRequestsQueries
  alias InternalApi.Plumber.{
    ScheduleResponse,
    DescribeResponse,
    TerminateResponse,
    ValidateYamlResponse,
    VersionResponse,
    ResponseStatus,
    ListResponse,
    GetProjectIdResponse,
    DescribeTopologyResponse,
    ScheduleExtensionResponse,
    DescribeManyResponse,
    PartialRebuildResponse,
    DeleteResponse,
    ListQueuesResponse,
    QueueType,
    ListGroupedResponse,
    ListActivityResponse,
    ListKeysetResponse
  }
  alias InternalApi.Plumber.{Block, EnvVariable, GitRefType, Triggerer}
  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias InternalApi.Plumber.Pipeline.{State, Result, ResultReason}
  alias InternalApi.PlumberWF.TriggeredBy
  alias Google.Protobuf.Timestamp
  alias Ppl.Grpc.InFlightCounter

  # Schedule

  def schedule(schedule_request, _stream) do
    Metrics.benchmark("Ppl.schedule", __MODULE__,  fn ->
      with  {:ok, false}             <- project_deleted?(schedule_request.project_id),
            request_map              <- string_keys(schedule_request),
            {:ok, schedule_params}   <- Actions.form_schedule_params(request_map),
            {:ok, %{ppl_id: ppl_id}} <- Actions.schedule(schedule_params, true, true)
      do
        map = %{ppl_id: ppl_id, response_status: %{code: :OK, message: ""}}
        Proto.deep_new!(ScheduleResponse, map)
      else
        {:error, {:project_deleted, project_id}} ->
          responed_refused(ScheduleResponse, "Project with id #{project_id} was deleted.")
        {:limit, msg}  ->
          %{ppl_id: "", response_status: limit_status(msg)} |> ScheduleResponse.new()
        e ->
          %{ppl_id: "", response_status: error_status(e)} |> ScheduleResponse.new()
      end
    end)
  end

  # Describe

  def describe(describe_request, _stream) do
    InFlightCounter.register(:describe)

    Metrics.benchmark("Ppl.describe", __MODULE__,  fn ->
      with {:ok, ppl, blocks} <- Actions.describe(describe_request),
           description        <- %{pipeline: ppl, blocks: blocks,
                                   response_status: %{code: :OK, message: ""}},
           {:ok, response}    <- Proto.deep_new(DescribeResponse, description,
                                    transformations: trasnformation_functions())
      do
        response
      else
        e -> %{response_status: error_status(e)} |> DescribeResponse.new()
      end
    end)
  end

  # DescribeMany

  def describe_many(request, _) do
    InFlightCounter.register(:describe)

    Metrics.benchmark("Ppl.describe_many", __MODULE__,  fn ->
      with {:ok, pipelines} <- Actions.describe_many(request),
           response_map     <- %{pipelines: pipelines, response_status: %{code: :OK}},
           {:ok, response}  <- Proto.deep_new(DescribeManyResponse, response_map,
                                              transformations: trasnformation_functions())
      do
        response
      else
        e -> %{response_status: error_status(e)} |> DescribeManyResponse.new()
      end
    end)
  end

  defp trasnformation_functions() do
   %{
      Timestamp => {__MODULE__, :date_time_to_timestamps},
      State => {__MODULE__, :string_to_enum_atom_or_0},
      Result => {__MODULE__, :string_to_enum_atom_or_0},
      ResultReason => {__MODULE__, :string_to_enum_atom_or_0},
      QueueType => {__MODULE__, :string_to_enum_atom_or_0},
      Block.State => {__MODULE__, :string_to_enum_atom_or_0},
      Block.Result => {__MODULE__, :string_to_enum_atom_or_0},
      Block.ResultReason => {__MODULE__, :string_to_enum_atom_or_0},
      TriggeredBy => {__MODULE__, :string_to_enum_atom_or_0},
      GitRefType => {__MODULE__, :string_to_enum_atom_or_0},
      EnvVariable => {__MODULE__, :env_var_string_keys_to_atoms},
      Triggerer => {__MODULE__, :parse_triggerer}
    }
  end

  def parse_triggerer(_, triggerer_data), do: TriggererModel.to_grpc(triggerer_data)

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}
  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end
  def date_time_to_timestamps(_field_name, value), do: value

  def string_to_enum_atom_or_0(_field_name, field_value)
    when is_binary(field_value) and field_value != "" do
      field_value |> String.upcase() |> String.to_atom()
  end
  def string_to_enum_atom_or_0(_field_name, _field_value), do: 0

  def env_var_string_keys_to_atoms(_field_name, env_var_map) do
    %{name: Map.get(env_var_map, "name", ""), value: Map.get(env_var_map, "value", "")}
  end

  # Terminate

  def terminate(terminate_request, _stream) do
    Metrics.benchmark("Ppl.terminate", __MODULE__,  fn ->
      with params            <- terminate_request |> string_keys(),
           {:ok, message}    <- Actions.terminate(params)
      do
        map = %{response_status: %{code: :OK, message: message}}
        Proto.deep_new!(TerminateResponse, map)

      else
        e ->  %{response_status: error_status(e)} |> TerminateResponse.new()
      end
    end)
  end

  # GetProjectId

  def get_project_id(request, _stream) do
    Metrics.benchmark("Ppl.get_project_id", __MODULE__,  fn ->
      with ppl_id             <- request.ppl_id,
           {:ok, _}           <- UUID.info(ppl_id),
           {:ok, ppl}         <- PplsQueries.get_by_id(ppl_id),
           {:ok, project_id}  <- ppl |> Map.fetch(:project_id)
      do
         map =  %{project_id: project_id, response_status: %{code: :OK, message: ""}}
         Proto.deep_new!(GetProjectIdResponse, map)
      else
        e ->  %{response_status: error_status(e)} |> GetProjectIdResponse.new()
      end
    end)
  end

  # ValidateYaml

  def validate_yaml(request, _stream) do
    Metrics.benchmark("Ppl.validate_yaml", __MODULE__,  fn ->
      with {:ok, valid_definition} <- DefinitionValidator.validate_yaml_string(request.yaml_definition),
           {:ok, ppl_id}           <- schedule_rebuld?(request, valid_definition)
      do
        map =  %{ppl_id: ppl_id, response_status: %{code: :OK, message: "YAML definition is valid."}}
        Proto.deep_new!(ValidateYamlResponse, map)
      else
        {:error, {:project_deleted, project_id}} ->
          responed_refused(ValidateYamlResponse, "Project with id #{project_id} was deleted.")
        e ->
          %{response_status: error_status(e)} |> ValidateYamlResponse.new()
      end
    end)
  end

  defp schedule_rebuld?(%{ppl_id: ppl_id}, _valid_definition)
    when is_nil(ppl_id) or ppl_id == "", do: {:ok, ""}

  defp schedule_rebuld?(request, definition) do
    with {:ok, prev_ppl_req} <- PplRequestsQueries.get_by_id(request.ppl_id),
         {:ok, project_id}   <- Map.fetch(prev_ppl_req.request_args, "project_id"),
         {:ok, false}        <- project_deleted?(project_id),
         {:ok, params}       <- extract_schedule_params(prev_ppl_req),
    do:  Actions.schedule_with_definition(params, definition, request.yaml_definition, true, false)
  end

  defp extract_schedule_params(ppl_req) do
    ppl_req.request_args
    |> Map.put("request_token", UUID.uuid4())
    |> Map.put("wf_id", ppl_req.wf_id)
    |> ToTuple.ok()
  end

  # DescribeTopology

  def describe_topology(request, _stream) do
    Metrics.benchmark("Ppl.describe_topology", __MODULE__, fn ->
      with ppl_id             <- request.ppl_id,
           {:ok, ppl_request} <- PplRequestsQueries.get_by_id(ppl_id),
           true               <- ppl_request != nil,
           {:ok, topology}    <- Actions.describe_topology(ppl_request.definition)
      do
        params = topology
          |> Map.put(:status, %{code: :OK, message: ""})

        Proto.deep_new!(InternalApi.Plumber.DescribeTopologyResponse, params)
      else
        e -> %{status: error_status(e)} |> DescribeTopologyResponse.new()
      end
    end)
  end

  # ListKeyset

  def list_keyset(request, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("Ppl.list_keyset", __MODULE__,  fn ->
      with {:ok, pipelines}  <- Actions.list_keyset(request),
           {:ok, results}    <- Proto.deep_new(pipelines, ListKeysetResponse,
                                  transformations: trasnformation_functions())
      do
        results
      else
        {:error, {:invalid_arg, msg}} ->
          raise GRPC.RPCError, status: GRPC.Status.invalid_argument, message: msg
        {:error, msg} ->
          raise GRPC.RPCError, status: GRPC.Status.internal, message: msg
      end
    end)
  end

  # List

  def list(list_request, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("Ppl.list", __MODULE__,  fn ->
      with {:ok, params} <- Actions.list_ppls(list_request),
           {:ok, result} <- rename_entries(params, :pipelines)
      do
        map = %{response_status: %{code: :OK, message: ""}} |> Map.merge(result)
        Proto.deep_new!(ListResponse, map,
                transformations: trasnformation_functions())
      else
        e -> respond(ListResponse, :BAD_PARAM, e)
      end
    end)
  end

  # ListQueues

  def list_queues(lq_request, _stream) do
    InFlightCounter.register(:list)

    Metrics.benchmark("Ppl.list_queues", __MODULE__,  fn ->
      with {:ok, result} <- Actions.list_queues(lq_request),
           {:ok, result} <- rename_entries(result, :queues)
      do
        map = %{response_status: %{code: :OK, message: ""}} |> Map.merge(result)
        Proto.deep_new!(ListQueuesResponse, map,
          transformations: %{QueueType => {__MODULE__, :string_to_enum_atom_or_0}})
      else
        {:error, msg} -> respond(ListQueuesResponse, :BAD_PARAM, msg)
      end
    end)
  end

  defp rename_entries(result, new_name) do
    result
    |> Map.from_struct()
    |> Map.put(new_name, result.entries)
    |> Map.delete(:entries)
    |> ToTuple.ok()
  end

  defp respond(module, code, {:error, e}), do: respond(module, code, e)
  defp respond(module, code, message) do
    params = %{response_status: %{code: code, message: to_str(message)}}
    Proto.deep_new!(module, params)
  end

  #ListGrouped

  def list_grouped(lgr_req, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("Ppl.list_grouped", __MODULE__,  fn ->
      with {:ok, result}   <- Actions.list_grouped(lgr_req),
           resp_status     <- %{response_status: %{code: :OK, message: ""}},
           map             <- Map.merge(resp_status, result),
           {:ok, response} <- Proto.deep_new(ListGroupedResponse, map,
                                transformations: trasnformation_functions(),
                                string_keys_to_atoms: true)
       do
        response
       else
         {:error, msg} -> respond(ListGroupedResponse, :BAD_PARAM, msg)
       end
    end)
  end

  # ListActivity

  def list_activity(request, _stream) do
    InFlightCounter.register(:list)

    Metrics.benchmark("Ppl.list_activity", __MODULE__,  fn ->
      with {:ok, result}   <- ListActivityImpl.list_activity(request),
           {:ok, response} <- Proto.deep_new(ListActivityResponse, result,
                                transformations: trasnformation_functions())
       do
        response
       else
         {:error, {:invalid_arg, msg}} ->
           raise GRPC.RPCError, status: GRPC.Status.invalid_argument, message: msg
         {:error, msg} ->
           raise GRPC.RPCError, status: GRPC.Status.internal, message: msg
       end
    end)
  end

  # ScheduleExtension

  def schedule_extension(se_request, _stream) do
    Metrics.benchmark("Ppl.schedule_extension", __MODULE__,  fn ->
      with  {:ok, initial_ppl_req}   <- PplRequestsQueries.get_by_id(se_request.ppl_id),
            {:ok, initial_ppl}       <- PplsQueries.get_by_id(se_request.ppl_id),
            {:ok, project_id}        <- Map.fetch(initial_ppl_req.request_args, "project_id"),
            {:ok, false}             <- project_deleted?(project_id),
            {:ok, schedule_params}   <- prepare_extension_params(se_request, initial_ppl_req, initial_ppl),
            {:ok, %{ppl_id: ppl_id}} <- Actions.schedule(schedule_params, true, false)
      do
        %{ppl_id: ppl_id, response_status: ok_status()} |> ScheduleExtensionResponse.new()
      else
        {:error, {:project_deleted, project_id}} ->
          responed_refused(ScheduleExtensionResponse, "Project with id #{project_id} was deleted.")
        e ->
          %{ppl_id: "", response_status: error_status(e)} |> ScheduleExtensionResponse.new()
      end
    end)
  end

  # ListRequesters

  def list_requesters(request, _stream) do
    InFlightCounter.register(:list)

    Metrics.benchmark("Ppl.list_requesters", __MODULE__,  fn ->
      case Actions.list_requesters(request) do
        {:ok, response} ->
          response
        {:error, {:BAD_PARAM, msg}} ->
          raise GRPC.RPCError,
            status: GRPC.Status.invalid_argument(),
            message: "Listing requesters failed with: #{inspect(msg)}"

        {:error, error} ->
          raise GRPC.RPCError,
            status: GRPC.Status.internal(),
            message: "Listing requesters failed with: #{inspect(error)}"
      end
    end)
  end

  defp prepare_extension_params(request, initial_ppl_req, initial_ppl) do
    initial_ppl_req.request_args
    |> Map.put("wf_id", initial_ppl_req.wf_id)
    |> copy_wf_no(initial_ppl)
    |> Map.put("extension_of", request.ppl_id)
    |> Map.put("deployment_target_id", request.deployment_target_id)
    |> Map.put("env_vars", request.env_variables |> transform_env_vars())
    |> Map.put("request_secrets", request.secret_names |> transform_secrets())
    |> Map.put("prev_ppl_artefact_ids", request.prev_ppl_artefact_ids)
    |> Map.put("request_token", request.request_token)
    |> Map.put("file_name", request.file_path)
    |> Map.put("promoter_id", request.promoted_by)
    |> Map.put("auto_promoted", request.auto_promoted)
    |> ToTuple.ok()
  end

  defp copy_wf_no(map, %{wf_number: num}) when is_integer(num) and num > 0 do
    map |> Map.put("wf_number", num)
  end
  defp copy_wf_no(map, _initil_ppl), do: map

  defp transform_env_vars(env_vars) do
    env_vars
    |> Enum.map(fn proto_msg ->
      proto_msg |> Map.from_struct() |> string_keys()
    end)
  end

  defp transform_secrets(secret_names) do
    secret_names
    |> Enum.map(fn secret_name ->
      %{"name" => secret_name}
    end)
  end

  # PartialRebuild

  def partial_rebuild(pr_request, _stream) do
    Metrics.benchmark("Ppl.partial_rebuild", __MODULE__,  fn ->
      with {:ok, request}     <- Proto.to_map(pr_request),
           {:ok, ppl}         <- PplsQueries.get_by_id(request.ppl_id),
           {:ok, false}       <- project_deleted?(ppl.project_id),
           {"done", result} when result != "passed"
                              <- {ppl.state, ppl.result},
            {:ok, ppl_req}     <- PplRequestsQueries.get_by_id(request.ppl_id),
            {:ok}              <- verify_deployment_target_permission(ppl_req, request.user_id),
            {:ok, ppl_id}     <- Actions.partial_rebuild(request)
      do
        Proto.deep_new!(PartialRebuildResponse,
                        %{ppl_id: ppl_id, response_status: %{code: :OK}})
      else
        {:error, {:project_deleted, project_id}} ->
          responed_refused(PartialRebuildResponse, "Project with id #{project_id} was deleted.")
        {:error, {:deployment_target_permission_denied, reason}} ->
          rebuild_error_resp("Access to deployment target denied: #{inspect reason}")
        {:error, message} ->
          rebuild_error_resp("#{inspect message}")
        {"done", "passed"} ->
          rebuild_error_resp("Pipelines which passed can not be partial rebuilt.")
        {state, _result} when is_binary(state) ->
          rebuild_error_resp("Only pipelines which are in done state can be partial rebuilt.")
        error ->
          rebuild_error_resp("#{inspect error}")
      end
    end)
  end

  defp rebuild_error_resp(message) do
    Proto.deep_new!(PartialRebuildResponse, %{response_status: %{code: :BAD_PARAM, message: message}})
  end

  # Delete

  def delete(delete_request, _stream) do
    Metrics.benchmark("Ppl.delete", __MODULE__,  fn ->
      case delete_request |> Proto.to_map() |> Actions.delete() do
        {:ok, message} ->
          Proto.deep_new!(DeleteResponse, %{status: %{code: :OK, message: message}})
        {:error, message} ->
          Proto.deep_new!(DeleteResponse, %{status: %{code: :BAD_PARAM, message: message}})
      end
    end)
  end

  # Version

  def version(_, _stream) do
    version = :application.loaded_applications
      |> Enum.find(fn {k, _, _} -> k == :ppl end)
      |> elem(2)
      |> List.to_string

    VersionResponse.new(version: version)
  end

  # Utility

  defp project_deleted?(project_id) do
    case DeleteRequestsQueries.project_deletion_requested?(project_id) do
      {:ok, true} -> {:error, {:project_deleted, project_id}}
      other -> other
    end
  end

  defp responed_refused(module, message) do
    params = %{response_status: %{code: :REFUSED, message: message}}
    Proto.deep_new!(module, params)
  end

  defp ok_status(),
    do: ResponseStatus.new(code: ResponseCode.value(:OK), message: "")

  defp error_status({:error, message}),
    do: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: to_str(message))

  defp error_status(message),
    do: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: to_str(message))

  defp limit_status(message),
    do: ResponseStatus.new(code: ResponseCode.value(:LIMIT_EXCEEDED), message: to_str(message))

  defp verify_deployment_target_permission(%{request_args: %{"deployment_target_id" => ""}}, _user_id), do: {:ok}
  defp verify_deployment_target_permission(%{request_args: %{"deployment_target_id" => nil}}, _user_id), do: {:ok}
  defp verify_deployment_target_permission(%{
    request_args: %{"deployment_target_id" => deployment_target_id, "label" => label},
    source_args: %{"git_ref_type" => git_ref_type}
  }, user_id) when is_binary(git_ref_type) and is_binary(label) and label != "" do
    case GoferClient.verify_deployment_target_access(deployment_target_id, user_id, git_ref_type, label) do
      {:ok, :access_granted} -> {:ok}
      {:error, reason} -> {:error, {:deployment_target_permission_denied, reason}}
      error -> {:error, {:deployment_target_permission_denied, error}}
    end
  end
  defp verify_deployment_target_permission(%{request_args: %{"deployment_target_id" => deployment_target_id}}, _user_id) when is_binary(deployment_target_id) and deployment_target_id != "",
   do: {:error, {:deployment_target_permission_denied, "Missing label or git_ref_type"}}
  defp verify_deployment_target_permission(_, _), do: {:ok}

  defp string_keys(map), do: map |> Poison.encode!() |> Poison.decode!()

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
