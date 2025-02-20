formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(
  exclude: [integration: true],
  capture_log: true,
  formatters: formatters
)

ExUnit.start()

GrpcMock.defmock(RepoHubMock, for: InternalApi.Repository.RepositoryService.Service)
GrpcMock.defmock(UserServiceMock, for: InternalApi.User.UserService.Service)
GrpcMock.defmock(ArtifactServiceMock, for: InternalApi.Artifacthub.ArtifactService.Service)
GrpcMock.defmock(ProjectServiceMock, for: InternalApi.Projecthub.ProjectService.Service)

GrpcMock.defmock(OrganizationServiceMock,
  for: InternalApi.Organization.OrganizationService.Service
)

GrpcMock.defmock(
  PFCServiceMock,
  for: InternalApi.PreFlightChecksHub.PreFlightChecksService.Service
)

defmodule Test.Helpers do
  use ExUnit.Case

  def query_params() do
    %{
      initial_query: Ppl.Ppls.Model.Ppls,
      cooling_time_sec: -2,
      repo: Ppl.EctoRepo,
      schema: Ppl.Ppls.Model.Ppls,
      returning: [:id, :ppl_id],
      allowed_states: ~w(initializing pending queuing running stopping done)
    }
  end

  def to_state(ppl, state, opts \\ [])

  def to_state({:ok, ppl}, state, opts), do: to_state(ppl, state, opts)

  def to_state(ppl, state, opts) do
    with_traces = Keyword.get(opts, :with_traces, false)
    result = Keyword.get(opts, :result, "passed")

    args = query_params()

    Looper.STM.Impl.exit_scheduling(
      ppl,
      fn _, _ -> {:ok, %{state: state, result: result}} end,
      args
    )

    if with_traces do
      ~w(pending_at queuing_at running_at done_at)a
      |> Enum.each(fn state_trace_name ->
        Ppl.PplTraces.Model.PplTracesQueries.set_timestamp(ppl.ppl_id, state_trace_name)
        :timer.sleep(500)
      end)
    end

    Ppl.Ppls.Model.PplsQueries.get_by_id(ppl.ppl_id)
  end

  def assert_finished_for_less_than(module, fun, args, timeout) do
    task = Task.async(module, fun, args)

    result = Task.yield(task, timeout)
    Task.shutdown(task)

    assert {:ok, _response} = result
  end

  def wait_for_ppl_state(ppl_id, desired_state, timeout \\ 1_000) do
    Test.Helpers.assert_finished_for_less_than(
      __MODULE__,
      :do_wait_for_ppl_state,
      [ppl_id, desired_state],
      timeout
    )
  end

  def do_wait_for_ppl_state(ppl_id, desired_state) do
    :timer.sleep(100)
    {:ok, description, _} = Ppl.Actions.describe(%{ppl_id: ppl_id})

    state = Map.get(description, :state)

    if state == desired_state do
      description
    else
      do_wait_for_ppl_state(ppl_id, desired_state)
    end
  end

  def truncate_db do
    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Ppl.EctoRepo, "truncate table pipeline_requests cascade;")

    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Ppl.EctoRepo, "truncate table latest_workflows cascade;")

    assert {:ok, _} = Ecto.Adapters.SQL.query(Ppl.EctoRepo, "truncate table delete_requests;")
    assert {:ok, _} = Ecto.Adapters.SQL.query(Ppl.EctoRepo, "truncate table queues;")

    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Ppl.EctoRepo, "truncate table after_ppl_tasks cascade;")

    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")
  end

  def start_all_loopers() do
    []
    # Ppls Loopers
    |> start_ppl_loopers()
    # PplSubInits Loopers
    |> start_sub_init_loopers()
    # PplBlocks Loopers
    |> start_ppl_block_loopers()
    # Blocks Loopers
    |> start_block_loopers()
    # After task Loppers
    |> start_after_ppl_task_loopers()
  end

  def start_ppl_loopers(loopers \\ []) do
    loopers
    |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.RunningState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.StoppingState.start_link()])
  end

  def start_sub_init_loopers(loopers \\ []) do
    loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.ConceivedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  def start_ppl_block_loopers(loopers \\ []) do
    loopers
    |> Enum.concat([Ppl.PplBlocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.WaitingState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.StoppingState.start_link()])
  end

  def start_block_loopers(loopers \\ []) do
    loopers
    # Blocks Loopers
    |> Enum.concat([Block.Blocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.StoppingState.start_link()])
    # Tasks Loopers
    |> Enum.concat([Block.Tasks.STMHandler.PendingState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.StoppingState.start_link()])
  end

  def start_after_ppl_task_loopers(loopers \\ []) do
    loopers
    |> Enum.concat([Ppl.AfterPplTasks.STMHandler.WaitingState.start_link()])
    |> Enum.concat([Ppl.AfterPplTasks.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.AfterPplTasks.STMHandler.RunningState.start_link()])
  end

  def stop_all_loopers(loopers) do
    loopers |> Enum.map(fn {_resp, pid} -> GenServer.stop(pid) end)
  end

  def schedule_request_factory(args \\ %{}, service_type),
    do: Test.Support.RequestFactory.schedule_args(args, service_type)

  def source_request_factory(args \\ %{}),
    do: Test.Support.RequestFactory.source_args(args)
end

defmodule Test.MockGoferService do
  use GRPC.Server, service: InternalApi.Gofer.Switch.Service

  alias InternalApi.Gofer.ResponseStatus.ResponseCode
  alias InternalApi.Gofer.{ResponseStatus, CreateResponse, PipelineDoneResponse}

  def create(_create_request, _stream) do
    response_type = Application.get_env(:gofer_client, :test_gofer_service_response)
    respond(response_type, :create)
  end

  def pipeline_done(_request, _stream) do
    response_type = Application.get_env(:gofer_client, :test_gofer_service_response)
    respond(response_type, :pipeline_done)
  end

  # Create
  defp respond("valid", :create) do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "")}
    |> Map.merge(%{switch_id: UUID.uuid4()})
    |> CreateResponse.new()
  end

  defp respond("bad_param", :create) do
    %{response_status: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: "Error")}
    |> Map.merge(%{switch_id: ""})
    |> CreateResponse.new()
  end

  defp respond("timeout", rpc_method) do
    :timer.sleep(5_000)
    response(rpc_method)
  end

  # PipelineDone
  defp respond("valid", :pipeline_done) do
    %{
      response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "Valid message")
    }
    |> PipelineDoneResponse.new()
  end

  defp respond(response_type, :pipeline_done) do
    code = response_type |> String.upcase() |> String.to_atom() |> ResponseCode.value()
    message = response_type |> String.upcase()

    %{response_status: ResponseStatus.new(code: code, message: message)}
    |> PipelineDoneResponse.new()
  end

  defp response(:create), do: CreateResponse.new()
  defp response(:pipeline_done), do: PipelineDoneResponse.new()
end
