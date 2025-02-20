defmodule Ppl.Ppls.STMHandler.DoneState.Test do
  @moduledoc """
  Test for the DoneState handler with GRPC server integration.
  Uses a dynamic port to avoid conflicts.
  """
  use Ppl.IntegrationCase

  alias Ppl.Ppls.STMHandler.DoneState.Test.Record
  alias Ppl.Ppls.STMHandler.DoneState.Test.RecordingGofer
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplRequests.Model.PplRequests
  alias Test.Helpers
  alias Ppl.EctoRepo, as: Repo

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(RecordingGofer)
  end

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end


  @tag :integration
  test "gofer service is called with valid params when ppl transitions to done", %{port: _port} = context do
    use_recording_gofer_service(context)

    assert {:ok, pid_r} = Record.start_link([])
    loopers = start_loopers()

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test", "file_name" => "promotions.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    :timer.sleep(5_000)
    ppl = Repo.get(Ppls, ppl.id)
    assert ppl.state == "running"

    ppl_req = Repo.get(PplRequests, ppl.ppl_id)
    assert ppl.ppl_id == ppl_req.switch_id

    # Manipulate PplBlocks in order to Ppl STM running handler transitions to done
    {:ok, _} = Repo.query("UPDATE pipeline_blocks SET state = 'done', result = 'passed';")

    args =[ppl.ppl_id]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    ppl = Repo.get(Ppls, ppl.id)
    assert ppl.state == "done"

    stop_loopers(loopers)
    Agent.stop(pid_r)
  end

  def check_state?(expected_id) do
    :timer.sleep 100

    if Record.get(:id) == expected_id do
      assert "passed" == Record.get(:result)
      :pass
    else
      check_state?(expected_id)
    end
  end

  defp use_recording_gofer_service(%{port: port}),
    do: Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)

  defp start_loopers() do
    []
    # Ppls loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.RunningState.start_link()])
    # PplSubInits loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(fn {:ok, pid} -> GenServer.stop(pid) end)
  end
end

defmodule Ppl.Ppls.STMHandler.DoneState.Test.RecordingGofer do
  use GRPC.Server, service: InternalApi.Gofer.Switch.Service

  alias InternalApi.Gofer.ResponseStatus.ResponseCode
  alias InternalApi.Gofer.{ResponseStatus, PipelineDoneResponse, CreateResponse}
  alias Ppl.Ppls.STMHandler.DoneState.Test.Record

  def create(request, _stream) do
    %{pipeline_id: id} = request

    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "Valid message"),
      switch_id: id
    }
    |> CreateResponse.new()
  end

  def pipeline_done(request, _stream) do
    %{switch_id: id, result: result} = request
    Record.set(:id, id)
    Record.set(:result, result)

    %{response_status: ResponseStatus.new(code: ResponseCode.value(:OK), message: "Valid message")}
    |> PipelineDoneResponse.new()
  end
end

defmodule Ppl.Ppls.STMHandler.DoneState.Test.Record do
   use Agent

   def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get(key) do
    Agent.get(__MODULE__, fn map -> Map.get(map, key) end)
  end

  def set(key, value) do
    Agent.update(__MODULE__, fn map -> Map.put(map, key, value) end)
  end
end
