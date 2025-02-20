defmodule Test.Support.WorkflowBuilder.Impl do
  @moduledoc """
  Serves for easier building of desired workflow topology for testing purposes.
  It initalizes with urls to Plumber and Gofer services and stores workflows with
  ids of all their scheduled pipelines.
  Each pipeline is modeled as:
    %{ppl_id: <id>, extensions: [], partial_rebuilds: []}
  where 'extensions' and 'partial_rebuilds' are lists of pipelines defined
  in same way.
  """

  use GenServer

  alias InternalApi.PlumberWF.{WorkflowService, ScheduleRequest}
  alias InternalApi.Plumber.{
    PipelineService,
    PartialRebuildRequest,
    ScheduleExtensionRequest
  }
  alias Util.Proto
  alias Ppl.PplRequests.Model.PplRequestsQueries

  def start_link(urls) do
    GenServer.start_link(__MODULE__, urls, name: :workflow_builder_impl)
  end

  def init(urls) do
    {:ok, {urls, %{}}}
  end

  def handle_call({:describe, wf_id}, _from, {urls, workflows}) do
    {:reply, Map.get(workflows, wf_id), {urls, workflows}}
  end

  def handle_call({:schedule, params}, _from, {urls, workflows}) do
    request = form_schedule_request(params)
    response = schedule_impl(request, urls)
    workflows = update_state(workflows, response, nil, :schedule)
    {:reply, response, {urls, workflows}}
  end

  def handle_call({:schedule_extension, wf_id, params}, _from, {urls, workflows}) do
    {:ok, ppl_req} = PplRequestsQueries.get_by_id(params.ppl_id)
    artefact_ids = ppl_req.prev_ppl_artefact_ids ++ [ppl_req.ppl_artefact_id]
    params = %{file_path: "/foo/bar/test.yml", request_token: UUID.uuid4(),
               prev_ppl_artefact_ids: artefact_ids} |> Map.merge(params)
    request =  Proto.deep_new!(ScheduleExtensionRequest, params)
    response = schedule_extension_impl(request, wf_id, urls)
    workflows = update_state(workflows, response, params.ppl_id, :extensions)
    {:reply, response, {urls, workflows}}
  end

  def handle_call({:partial_rebuild, wf_id, ppl_id}, _from, {urls, workflows}) do
    wait_for_ppl_state(ppl_id, %{state: :DONE, result: :FAILED}, 30_000)

    request = %{ppl_id: ppl_id, request_token: UUID.uuid4()} |> PartialRebuildRequest.new()
    response = partial_rebuild_impl(request, wf_id, urls)
    workflows = update_state(workflows, response, ppl_id, :partial_rebuilds)
    {:reply, response, {urls, workflows}}
  end

  defp update_state(workflows, {:ok, wf_id, ppl_id}, origin_id, type) do
    updated_workflow =
      workflows
      |> Map.get(wf_id, %{})
      |> update_origin(origin_id, ppl_id, type)

    workflows |> Map.put(wf_id, updated_workflow)
  end

  defp update_origin(%{}, nil, ppl_id, :schedule)  do
    %{ppl_id: ppl_id, extensions: [], partial_rebuilds: []}
  end

  defp update_origin(element, origin_id, ppl_id, type) when is_map(element) do
    if element.ppl_id == origin_id do
      new_child = %{ppl_id: ppl_id, extensions: [], partial_rebuilds: []}
      updated_list = element |> Map.get(type) |> Enum.concat([new_child])
      element |> Map.put(type, updated_list)
    else
      element
      |> Enum.map(fn {key, value} ->
        case key do
          :ppl_id -> {:ppl_id, value}
          _list_name -> {key, update_origin(value, origin_id, ppl_id, type)}
        end
      end)
      |> Enum.into(%{})
    end
  end

  defp update_origin(list, origin_id, ppl_id, type) when is_list(list) do
    list |> Enum.map(fn element ->
      update_origin(element, origin_id, ppl_id, type)
    end)
  end

  defp form_schedule_request(params) do
    req_params =
      %{"repo_name" => "20_workflow_builder", "service" => :LOCAL}
      |> Test.Support.RequestFactory.schedule_args(:local)
      |> Map.merge(params)
      |> group_fields(~w(owner repo_name branch_name commit_sha), "repo")

    Proto.deep_new!(ScheduleRequest, req_params, string_keys_to_atoms: true)
  end

  defp group_fields(request, fields, group_name) do
    ~w(owner, repo_name, branch_name, commit_sha)
    group = Enum.reduce(
                fields,
                %{},
                fn field, acc ->
                          %{}
                          |> Map.put(field, get_it_or_rand(request, field))
                          |> Map.merge(acc)
                        end
                )
    request |> Map.drop(fields) |> Map.put(group_name, group)
  end

  defp get_it_or_rand(request, filed), do: Map.get(request, filed) || UUID.uuid4()

  defp schedule_impl(request, urls) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect(urls.workflow_service)
    channel
    |> WorkflowService.Stub.schedule(request)
    |> case do
      {:ok, schedule_response} -> parse_schedule_resp(schedule_response)
      e = {:error, _msg} -> e
      error -> {:error, error}
    end
  end

  defp parse_schedule_resp(schedule_response) do
    with resp = %{status: %{code: :OK}}      <- Proto.to_map!(schedule_response),
         %{wf_id: wf_id} when wf_id != ""    <-  resp,
         %{ppl_id: ppl_id} when ppl_id != "" <-  resp,
    do: {:ok, wf_id, ppl_id}
  end

  defp partial_rebuild_impl(request, wf_id, urls) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect(urls.plumber_service)
    channel
    |> PipelineService.Stub.partial_rebuild(request)
    |> case do
      {:ok, %{ppl_id: ppl_id}} when ppl_id != "" -> {:ok, wf_id, ppl_id}
      e = {:error, _msg} -> e
      error -> {:error, error}
    end
  end

  defp schedule_extension_impl(request, wf_id, urls) do
    {:ok, channel} = GRPC.Stub.connect(urls.plumber_service)
    channel
    |> PipelineService.Stub.schedule_extension(request)
    |> case do
      {:ok, %{ppl_id: ppl_id}} when ppl_id != "" -> {:ok, wf_id, ppl_id}
      e = {:error, _msg} -> e
      error -> {:error, error}
    end
  end

  def wait_for_ppl_state(ppl_id, desired_state, timeout \\ 1_000) do
    assert_finished_for_less_than(__MODULE__, :do_wait_for_ppl_state,
                                 [ppl_id, desired_state], timeout)
  end

  def assert_finished_for_less_than(module, fun, args, timeout) do
    task = Task.async(module, fun, args)

    result = Task.yield(task, timeout)
    Task.shutdown(task)

    {:ok, response} = result
    response
  end

  def do_wait_for_ppl_state(ppl_id, desired_state) do
    :timer.sleep 100
    {:ok, ppl_desc, _} = Ppl.Actions.describe(%{ppl_id: ppl_id})

    desired_state =
      if is_atom(desired_state) do
        %{state: to_str_val(desired_state)}
      else
         desired_state
         |> Enum.map(fn {k, v} ->
           {k, to_str_val(v)}
         end)
         |> Enum.into(%{})
      end

    keys = desired_state |> Map.keys()
    real_state = ppl_desc |> Map.take(keys)

    if real_state == desired_state do
      ppl_desc
    else
      do_wait_for_ppl_state(ppl_id, desired_state)
    end
  end

  defp  to_str_val(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.downcase()
  defp  to_str_val(value) when is_binary(value), do: value
end
