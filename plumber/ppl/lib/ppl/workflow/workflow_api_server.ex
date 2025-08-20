defmodule Plumber.WorkflowAPI.Server do
  @moduledoc """
  GRPC server which exposes Workflow API
  """
  use GRPC.Server, service: InternalApi.PlumberWF.WorkflowService.Service

  alias GRPC.{RPCError, Status}
  alias Ppl.Actions
  alias Ppl.{WorkflowActions, WorkflowQueries}
  alias Util.{Metrics, Proto, ToTuple}
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.DeleteRequests.Model.DeleteRequestsQueries
  alias InternalApi.PlumberWF.ListGroupedRequest.SourceType
  alias InternalApi.PlumberWF.{
    CreateResponse,
    ScheduleResponse,
    TerminateResponse,
    GetPathResponse,
    ListResponse,
    DescribeResponse,
    DescribeManyResponse,
    GetProjectIdResponse,
    ListLabelsResponse,
    ListGroupedResponse,
    ListKeysetResponse,
    ListGroupedKSResponse,
    ListLatestWorkflowsResponse
  }
  alias InternalApi.PlumberWF.{GitRefType, TriggeredBy}
  alias Google.Protobuf.Timestamp
  alias Ppl.Grpc.InFlightCounter

  import Ppl.Actions.ListImpl, only: [non_empty_value_or_default: 3, first_before_second: 3, extract_timestamps: 2]

  def schedule(schedule_request, _stream) do
    Metrics.benchmark("WorkflowPB.schedule", __MODULE__, fn ->
      with {:ok, false} <- project_deleted?(schedule_request.project_id),
           {:ok, _org_id} <- id_present?(schedule_request, "organization_id"),
           {:ok, request_map} <- Proto.to_map(schedule_request, string_keys: true),
           {:ok, schedule_params} <- Actions.form_schedule_params(request_map),
           start_in_conceived?    <- start_in_conceived_state?(schedule_params),
           {:ok, result}          <- Actions.schedule(schedule_params, true, true, start_in_conceived?)
      do
        schedule_response(result.wf_id, result.ppl_id)
      else
        {:error, {:project_deleted, project_id}} ->
          respond(ScheduleResponse, :FAILED_PRECONDITION,
                  "Project with id #{project_id} was deleted.")
        {:limit, msg}  ->
          respond(ScheduleResponse, :RESOURCE_EXHAUSTED, msg)
        error ->
          respond(ScheduleResponse, :INVALID_ARGUMENT, error)
      end
    end)
  end

  def reschedule(rsch_request, _stream) do
    Metrics.benchmark("WorkflowPB.reschedule", __MODULE__,  fn ->
      with  {:ok, prev_ppl_req}    <- PplRequestsQueries.get_initial_wf_ppl(rsch_request.wf_id),
            {:ok, project_id}      <- Map.fetch(prev_ppl_req.request_args, "project_id"),
            {:ok, false}           <- project_deleted?(project_id),
            {:ok, schedule_params} <- extract_schedule_params(prev_ppl_req, rsch_request),
            {:ok, result}          <- Actions.schedule(schedule_params, true, true)
      do
        schedule_response(result.wf_id, result.ppl_id)
      else
        {:error, {:project_deleted, project_id}} ->
          respond(ScheduleResponse, :FAILED_PRECONDITION,
                  "Project with id #{project_id} was deleted.")
        {:limit, msg}  ->
          respond(ScheduleResponse, :RESOURCE_EXHAUSTED, msg)
        error ->
          respond(ScheduleResponse, :INVALID_ARGUMENT, error)
      end
    end)
  end

  defp schedule_response(wf_id, ppl_id) do
    map = %{wf_id: wf_id, ppl_id: ppl_id, status: %{code: :OK, message: ""}}
    Proto.deep_new!(ScheduleResponse, map)
  end

  defp extract_schedule_params(ppl_req, rsch_request) do
    ppl_req.request_args
    |> Map.put("request_token", rsch_request.request_token)
    |> Map.put("requester_id", rsch_request.requester_id)
    |> Map.put("wf_id", UUID.uuid4())
    |> Map.put("wf_rebuild_of", ppl_req.wf_id)
    |> set_label(ppl_req.id)
    |> ToTuple.ok()
  end

  defp set_label(map = %{"label" => _label}, _ppl_id), do: map
  defp set_label(request_args, ppl_id) do
    with {:ok, ppl} <- PplsQueries.get_by_id(ppl_id),
    do: request_args |> Map.put("label", ppl.label)
  end

  def get_path(path_request, _stream) do
    Metrics.benchmark("WorkflowPB.get_path", __MODULE__,  fn ->
      with {:ok, first_ppl_a_id} <- WorkflowActions.get_frist_ppl_artefact_id(path_request),
           {:ok, last_ppl_req}   <- WorkflowActions.get_last_ppl_req(path_request),
           {:ok, full_path}      <- WorkflowActions.find_path(first_ppl_a_id, last_ppl_req),
           {:ok, wf_details}     <- WorkflowActions.get_wf_details(last_ppl_req.wf_id)
      do
        map = %{path: full_path, status: %{code: :OK, message: ""}} |> Map.merge(wf_details)
        Proto.deep_new!(GetPathResponse, map, transformations: transformation_functions())
      else
        {:error, msg} ->
          respond(GetPathResponse, :FAILED_PRECONDITION, msg)
        error ->
          respond(GetPathResponse, :FAILED_PRECONDITION, error)
      end
    end)
  end

  def describe(desc_req, _) do
    InFlightCounter.register(:describe)

    Metrics.benchmark("WorkflowPB.describe", __MODULE__,  fn ->
      with {:ok, wf_id}     <- not_empty_string(desc_req, :wf_id),
           {:ok, wf}        <- WorkflowQueries.get_details(wf_id)
      do
        map = %{status: %{code: :OK, message: ""}} |> Map.merge(%{workflow: wf})
        Proto.deep_new!(DescribeResponse, map, transformations: transformation_functions())
      else
        {:error, msg} ->
          respond(DescribeResponse, :FAILED_PRECONDITION, msg)
        error ->
          respond(DescribeResponse, :FAILED_PRECONDITION, error)
      end
    end)
  end

  def describe_many(desc_many_req, _) do
    Metrics.benchmark("WorkflowPB.describe_many", __MODULE__,  fn ->
      with {:ok, wf_ids}    <- not_empty_list_of_not_empty_strings(desc_many_req, :wf_ids),
           wfs              <- WorkflowQueries.get_workflows(wf_ids)
      do
        map = %{status: %{code: :OK, message: ""}} |> Map.merge(%{workflows: wfs})
        Proto.deep_new!(DescribeManyResponse, map, transformations: transformation_functions())
      else
        {:error, msg} ->
          respond(DescribeManyResponse, :FAILED_PRECONDITION, msg)
        error ->
          respond(DescribeManyResponse, :FAILED_PRECONDITION, error)
      end
    end)
  end

  def list_grouped(lgr_req, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("WorkflowPB.list_grouped", __MODULE__,  fn ->
      with  tf_map            <- %{SourceType => {__MODULE__, :transform_grouped_by},
                                   GitRefType => {__MODULE__, :git_ref_to_lower_string}},
            {:ok, params}     <- Proto.to_map(lgr_req, transformations: tf_map),
            {:ok, project_id} <- not_empty_string(params, :project_id),
            {:ok, page}       <- non_empty_value_or_default(params, :page, 1),
            {:ok, page_size}  <- non_empty_value_or_default(params, :page_size, 30),
            {:ok, ref_types}  <- non_empty_value_or_default(params, :git_ref_types, :skip),
            query_params      <- %{project_id: project_id, git_ref_types: ref_types},
            {:ok, result}     <- WorkflowQueries.list_grouped(query_params, page, page_size)
       do
         %{status: %{code: :OK, message: ""}}
         |> Map.merge(result)
         |> Proto.deep_new!(ListGroupedResponse, string_keys_to_atoms: true,
                                   transformations: string_key_trasnformations())
       else
         {:error, msg} -> respond(ListGroupedResponse, :INVALID_ARGUMENT, msg)
       end
    end)
  end

  def list_grouped_ks(lgr_req, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("WorkflowPB.list_grouped_ks", __MODULE__,  fn ->
      with  tf_map            <- %{GitRefType => {__MODULE__, :git_ref_to_lower_string}},
            {:ok, params}     <- Proto.to_map(lgr_req, transformations: tf_map),
            {:ok, project_id} <- not_empty_string(params, :project_id, :invalid_arg),
            {:ok, page_size}  <- non_empty_value_or_default(params, :page_size, 30),
            {:ok, ref_types}  <- non_empty_value_or_default(params, :git_ref_types, :skip),
            {:ok, user_id}    <- non_empty_value_or_default(params, :requester_id, :skip),
            {:ok, token_vals} <- params |> Map.get(:page_token) |> parse_token(),
            query_params      <- %{project_id: project_id, git_ref_types: ref_types,
                                   requester_id: user_id, token_vals: token_vals,
                                   direction: params.direction},
            {:ok, page}       <- WorkflowQueries.list_grouped_ks(query_params, page_size)
       do
         %{status: %{code: :OK, message: ""}}
         |> Map.merge(page)
         |> Proto.deep_new!(ListGroupedKSResponse, string_keys_to_atoms: true,
                                   transformations: string_key_trasnformations())
       else
         {:error, {:invalid_arg, msg}} ->
           raise GRPC.RPCError, status: GRPC.Status.invalid_argument, message: msg
         {:error, msg} ->
           raise GRPC.RPCError, status: GRPC.Status.internal, message: msg
       end
    end)
  end

  def list_latest_workflows(request, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("WorkflowPB.list_latest_workflows", __MODULE__,  fn ->
      with {:ok, params}        <- Proto.to_map(request, transformations:
                                             %{GitRefType => {__MODULE__, :git_ref_to_lower_string}}),
           {:ok, project_id}    <- not_empty_string(params, :project_id, :invalid_arg),
           {:ok, page_size}     <- non_empty_value_or_default(params, :page_size, 30),
           {:ok, git_ref_types} <- non_empty_value_or_default(params, :git_ref_types, nil),
           {:ok, user_id}       <- non_empty_value_or_default(params, :requester_id, nil),
           {:ok, page_token}    <- non_empty_value_or_default(params, :page_token, nil),
           query_params         <- %{
             project_id: project_id,
             git_ref_types: git_ref_types,
             requester_id: user_id,
             page_token: page_token,
             direction: params.direction,
             page_size: page_size},
           {:ok, page}          <- WorkflowQueries.list_latest_workflows(query_params)
      do
        %{status: %{code: :OK, message: ""}}
        |> Map.merge(page)
        |> Proto.deep_new!(ListLatestWorkflowsResponse, transformations: transformation_functions())
      else
        {:error, {:invalid_arg, msg}} ->
          raise GRPC.RPCError, status: GRPC.Status.invalid_argument, message: msg
        {:error, msg} ->
          raise GRPC.RPCError, status: GRPC.Status.internal, message: msg
      end
    end)
  end

  defp parse_token(""), do: {:ok, nil}
  defp parse_token(token) when is_binary(token) do
    case Paginator.Cursor.decode(token) do
      %{id: id, inserted_at: inserted_at} ->
        %{id: id, inserted_at: inserted_at} |> ToTuple.ok()
      _ ->
         "Invalid page_token value: '#{token}'" |> ToTuple.error(:invalid_argument)
    end
  rescue
    _ -> "Invalid page_token value: '#{token}'" |> ToTuple.error(:invalid_argument)
  end

  def list_keyset(list_req, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("WorkflowPB.list_keyset", __MODULE__,  fn ->
      with tf_map          <- %{Timestamp => {__MODULE__, :timestamp_to_datetime},
                                TriggeredBy => {__MODULE__, :triggerd_by_to_lower_string},
                                GitRefType => {__MODULE__, :git_ref_to_lower_string}},
       {:ok, params}       <- Proto.to_map(list_req, transformations: tf_map),
       {:ok, project_id}   <- non_empty_value_or_default(params, :project_id, :skip),
       {:ok, org_id}       <- non_empty_value_or_default(params, :organization_id, :skip),
       {:ok, projects}     <- non_empty_value_or_default(params, :project_ids, :skip),
       true                <- one_of_required_present(project_id, projects, org_id),
       {:ok, branch_name}  <- non_empty_value_or_default(params, :branch_name, :skip),
       {:ok, label}        <- non_empty_value_or_default(params, :label, :skip),
       {:ok, ref_types}    <- non_empty_value_or_default(params, :git_ref_types, :skip),
       {:ok, requester_id} <- non_empty_value_or_default(params, :requester_id, :skip),
       {:ok, requesters}   <- non_empty_value_or_default(params, :requester_ids, :skip),
       {:ok, triggerers}   <- non_empty_value_or_default(params, :triggerers, :skip),
       {:ok, timestamps}   <- validate_timestamps(params),
       query_params        <- %{project_id: project_id, branch_name: branch_name,
                                projects: projects, org_id: org_id, label: label,
                                git_ref_types: ref_types, triggerers: triggerers,
                                requester_id: requester_id, requesters: requesters}
                              |> Map.merge(timestamps),
       {:ok, size}         <- non_empty_value_or_default(params, :page_size, 30),
       {:ok, token}        <- non_empty_value_or_default(params, :page_token, nil),
       keyset_params       <- %{page_token: token, direction: params.direction,
                                page_size: size, order: params.order},
       {:ok, page}         <- WorkflowQueries.list_keyset(query_params, keyset_params)
      do
        %{status: %{code: :OK, message: ""}}
        |> Map.merge(page)
        |> Proto.deep_new!(ListKeysetResponse, transformations: transformation_functions())
      else
        {:error, msg} -> respond(ListKeysetResponse, :INVALID_ARGUMENT, msg)
      end
    end)
  end

  def list(list_req, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("WorkflowPB.list", __MODULE__,  fn ->
      with tf_map              <- %{Timestamp => {__MODULE__, :timestamp_to_datetime},
                                    GitRefType => {__MODULE__, :git_ref_to_lower_string}},
           {:ok, params}       <- Proto.to_map(list_req, transformations: tf_map),
           {:ok, project_id}   <- non_empty_value_or_default(params, :project_id, :skip),
           {:ok, org_id}       <- non_empty_value_or_default(params, :organization_id, :skip),
           {:ok, projects}     <- non_empty_value_or_default(params, :project_ids, :skip),
           true                <- one_of_required_present(project_id, projects, org_id),
           {:ok, branch_name}  <- non_empty_value_or_default(params, :branch_name, :skip),
           {:ok, label}        <- non_empty_value_or_default(params, :label, :skip),
           {:ok, ref_types}    <- non_empty_value_or_default(params, :git_ref_types, :skip),
           {:ok, requester_id} <- non_empty_value_or_default(params, :requester_id, :skip),
           {:ok, page}         <- non_empty_value_or_default(params, :page, 1),
           {:ok, page_size}    <- non_empty_value_or_default(params, :page_size, 30),
           {:ok, timestamps}   <- validate_timestamps(params),
           query_params        <- %{project_id: project_id, branch_name: branch_name,
                                    projects: projects, org_id: org_id, label: label,
                                    git_ref_types: ref_types, requester_id: requester_id},
           query_params        <- query_params |> Map.merge(timestamps),
           {:ok, result}       <- WorkflowQueries.list_workflows(query_params, page, page_size),
           {:ok, result}       <- rename_entries(result, :workflows)
      do
        map = %{status: %{code: :OK, message: ""}} |> Map.merge(result)
        Proto.deep_new!(ListResponse, map, transformations: transformation_functions())
      else
        {:error, msg} -> respond(ListResponse, :INVALID_ARGUMENT, msg)
      end
    end)
  end

  defp start_in_conceived_state?(%{"scheduler_task_id" => val}) when is_binary(val) and val != "", do: true
  defp start_in_conceived_state?(%{"start_in_conceived_state" => val}), do: val

  defp one_of_required_present(:skip, :skip, :skip),
    do: {:error, "One of 'project_ids', 'project_id' or 'organization_id' parameters is required."}
  defp one_of_required_present(_project_id, _projects, _org_id), do: true

  def timestamp_to_datetime(_name, %{nanos: 0, seconds: 0}), do: :skip
  def timestamp_to_datetime(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  def transform_grouped_by(_name, value) do
    value |> SourceType.key() |> shorten_pr() |> Atom.to_string() |> String.downcase()
  end

  defp shorten_pr(:PULL_REQUEST), do: :PR
  defp shorten_pr(value), do: value

  def git_ref_to_lower_string(_name, value) do
    value |> GitRefType.key() |> Atom.to_string() |> String.downcase()
  end

  def triggerd_by_to_lower_string(_name, value) do
    value |> TriggeredBy.key() |> Atom.to_string() |> String.downcase()
  end

  defp validate_timestamps(params) do
    {:ok, params}
    |> date_times_or_default()
    |> first_before_second(:created_after, :created_before)
    |> extract_timestamps(false)
  end

  @query_ts_names ~w(created_before created_after)a

  defp date_times_or_default({:ok, map}) do
    timestamps =
      Enum.into(@query_ts_names, %{}, fn key ->
        {key, datetime_or_skip(map, key)}
      end)
    map |> Map.merge(timestamps) |> ToTuple.ok()
  end

  defp datetime_or_skip(map, key) do
    case Map.get(map, key) do
      nil -> :skip
      value = %DateTime{} -> value
      _ -> :skip
    end
  end

  defp rename_entries(result, new_name) do
    result
    |> Map.from_struct()
    |> Map.put(new_name, result.entries)
    |> Map.delete(:entries)
    |> ToTuple.ok()
  end

  def list_labels(ll_req, _) do
    InFlightCounter.register(:list)

    Metrics.benchmark("WorkflowPB.list", __MODULE__,  fn ->
      with {:ok, project_id}  <- not_empty_string(ll_req, :project_id),
           {:ok, page}        <- non_empty_value_or_default(ll_req, :page, 1),
           {:ok, page_size}   <- non_empty_value_or_default(ll_req, :page_size, 30),
           {:ok, result}      <- WorkflowQueries.list_labels(page, page_size, project_id),
           {:ok, result}      <- rename_entries(result, :labels)
      do
        map = %{status: %{code: :OK, message: ""}} |> Map.merge(result)
        Proto.deep_new!(ListLabelsResponse, map)
      else
        {:error, msg} -> respond(ListLabelsResponse, :INVALID_ARGUMENT, msg)
      end
    end)
  end

  def terminate(terminate_request, _stream) do
    Metrics.benchmark("WorkflowPB.terminate", __MODULE__,  fn ->
      with  {:ok, wf_id}        <- not_empty_string(terminate_request, :wf_id),
            {:ok, requester_id} <- not_empty_string(terminate_request, :requester_id),
            {:ok, _ppl}         <- PplRequestsQueries.get_initial_wf_ppl(wf_id),
            {:ok, t_params}     <- terminate_params(wf_id, requester_id),
            {:ok, number}       <- PplsQueries.terminate_all(t_params)
      do
        map = %{status: %{code: :OK, message: "Termination started for #{number} pipelines."}}
        Proto.deep_new!(TerminateResponse, map)
      else
        {:error, {:not_found, msg}} ->
          respond(TerminateResponse, :FAILED_PRECONDITION, msg)
        {:error, msg} ->
          respond(TerminateResponse, :INVALID_ARGUMENT, msg)
      end
    end)
  end

  defp not_empty_string(map, key, error_atom \\ "") do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" ->
        {:ok, value}
      error_val ->
        "'#{key}' - invalid value: '#{error_val}', it must be a not empty string."
        |> ToTuple.error(error_atom)
    end
  end

  defp not_empty_list_of_not_empty_strings(map, key, error_atom \\ "") do
    case Map.get(map, key) do
      value when is_list(value) ->
        case Enum.all?(value, &is_binary/1) do
          true -> {:ok, value |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))}
          false ->
            "'#{key}' - invalid value: '#{value}', it must be a list of strings."
            |> ToTuple.error(error_atom)
        end

      error_val ->
        "'#{key}' - invalid value: '#{error_val}', it must be a list of strings."
        |> ToTuple.error(error_atom)
    end
  end

  defp terminate_params(wf_id, requester_id) do
    %{wf_id: wf_id,
      terminated_by: requester_id,
      terminate_request: "stop",
      terminate_request_desc: "API call"
    } |> ToTuple.ok()
  end

  # GetProjectId

  def get_project_id(request, _stream) do
    Metrics.benchmark("WorkflowPB.get_project_id", __MODULE__,  fn ->
      with {:ok, wf_id}      <- not_empty_string(request, :wf_id),
           {:ok, ppl_req}    <- PplRequestsQueries.get_initial_wf_ppl(wf_id),
           {:ok, project_id} <- Map.fetch(ppl_req.request_args, "project_id")
      do
         map =  %{project_id: project_id, status: %{code: :OK, message: ""}}
         Proto.deep_new!(GetProjectIdResponse, map)
      else
        error ->
          respond(GetProjectIdResponse, :INVALID_ARGUMENT, error)
      end
    end)
  end

  # Create

  def create(request, _stream) do
    Metrics.benchmark("Wf.create", __MODULE__,  fn ->
      with  {:ok, false}             <- project_deleted?(request.project_id),
            {:ok, request_map}       <- Proto.to_map(request, string_keys: true),
            {:ok, schedule_params}   <- Actions.form_schedule_params(request_map),
            {:ok, result}            <- Actions.schedule(schedule_params, true, true)
      do
        %{wf_id: result.wf_id, ppl_id: result.ppl_id}
        |> Proto.deep_new!(CreateResponse)
      else
        {:error, {:project_deleted, project_id}} ->
          raise RPCError.exception(Status.failed_precondition(),
                  "Project with id #{project_id} was deleted.")
        {:limit, msg}  ->
          raise RPCError.exception(Status.resource_exhausted(), msg)
        error ->
          raise RPCError.exception(Status.invalid_argument(), inspect(error))
      end
    end)
  end

  # Utility

  defp string_key_trasnformations() do
   %{TriggeredBy => {__MODULE__, :string_to_enum_atom_or_0}}
  end

  defp transformation_functions() do
   %{Timestamp => {__MODULE__, :date_time_to_timestamps},
     TriggeredBy => {__MODULE__, :string_to_enum_atom_or_0}}
  end

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}
  def date_time_to_timestamps(_field_name, date_time) do
    seconds = date_time |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:second)
    %{}
    |> Map.put(:seconds, seconds)
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  def string_to_enum_atom_or_0(_field_name, field_value)
    when is_binary(field_value) and field_value != "" do
      field_value |> String.upcase() |> String.to_atom()
  end
  def string_to_enum_atom_or_0(_field_name, _field_value), do: 0

  # should be moved to changeset once pipeline schedule is no longer in use
  defp id_present?(%{requester_id: id}, "requester_id")
    when is_binary(id) and id != "", do: {:ok, id}
  defp id_present?(%{organization_id: id}, "organization_id")
    when is_binary(id) and id != "", do: {:ok, id}
  defp id_present?(request, id_name),
    do: {:error, "Missing or invalid value of '#{id_name}' param in '#{inspect request}'.'"}

  defp project_deleted?(project_id) do
    case DeleteRequestsQueries.project_deletion_requested?(project_id) do
      {:ok, true} -> {:error, {:project_deleted, project_id}}
      other -> other
    end
  end

  defp respond(module, code, {:error, e}), do: respond(module, code, e)
  defp respond(module, code, message) do
    params = %{status: %{code: code, message: to_str(message)}}
    Proto.deep_new!(module, params)
  end

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
