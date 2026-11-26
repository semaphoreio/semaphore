defmodule Ppl.Ppls.Beholder.Test do
  use Ppl.IntegrationCase

  import Mock

  alias InternalApi.Plumber.PipelineEvent
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias InternalApi.Plumber.Pipeline.Result
  alias Ppl.Actions
  alias Ppl.Ppls.Beholder
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.EctoRepo, as: Repo

  setup do
    Test.Helpers.truncate_db()

    :ok
  end

  test "pipeline is terminated when recovery counter reaches threshold" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert ppl.state == "initializing"

    assert {:ok, ppl} =
             ppl
             |> Ppls.changeset(%{recovery_count: 5, in_scheduling: true})
             |> Repo.update()

    assert ppl.recovery_count == 5
    assert ppl.in_scheduling == true

    assert {:ok, pid} = Beholder.start_link()
    args = [ppl.state, ppl, pid]
    Test.Helpers.assert_finished_for_less_than(__MODULE__, :transitioned_to_done, args, 5_000)
  end

  def transitioned_to_done(state, ppl, pid) when state != "done" do
    :timer.sleep(100)
    ppl = Repo.get(Ppls, ppl.id)
    transitioned_to_done(ppl.state, ppl, pid)
  end

  def transitioned_to_done("done", ppl, pid) do
    assert ppl.state == "done"
    assert ppl.in_scheduling == true
    assert ppl.recovery_count == 5
    Process.exit(pid, :normal)
  end

  test "recovery counter is incremented when pipeline is recovered from stuck" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)

    assert {:ok, looper_pid} = Beholder.start_link()

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert ppl.state == "initializing"
    assert {:ok, ppl} = to_scheduling("initializing")
    assert ppl.in_scheduling == true

    Test.Helpers.assert_finished_for_less_than(
      __MODULE__,
      :recovery_count_is_incremented_assert,
      [ppl.recovery_count, ppl, looper_pid],
      5_000
    )
  end

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

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: pple}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, pple}
  end

  def recovery_count_is_incremented_assert(recovery_count, ppl, looper_pid)
      when recovery_count == 0 do
    :timer.sleep(100)
    ppl = Repo.get(Ppls, ppl.id)

    recovery_count_is_incremented_assert(ppl.recovery_count, ppl, looper_pid)
  end

  def recovery_count_is_incremented_assert(_recovery_count, ppl, looper_pid) do
    assert ppl.recovery_count > 0
    Process.exit(looper_pid, :normal)
  end

  test "child_spec accepts 1 arg and returns a map" do
    assert Beholder.child_spec([]) |> is_map()
  end

  test "terminating blocks of a pipeline that has no blocks yet does not raise" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    assert {:error, _} = PplBlocksQueries.get_all_by_id(ppl.ppl_id)

    assert {:ok, 0} = Beholder.terminate_ppl_blks(ppl)
  end

  test "done event is published when a stuck pipeline without blocks is aborted" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    assert {:error, _} = PplBlocksQueries.get_all_by_id(ppl.ppl_id)

    with_mock Looper.Publisher.AMQP, publish: capture_publish() do
      Beholder.post_proccessing(ppl)
    end

    assert_done_event_published(ppl.ppl_id)
  end

  @tag :integration
  test "blocks are terminated and done event is published when terminating the sub-init fails" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    create_blocks(ppl_id)
    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    with_mocks [
      {PplSubInitsQueries, [:passthrough],
       terminate: fn _psi, _request, _desc -> raise "sub-init update failed" end},
      {Looper.Publisher.AMQP, [], publish: capture_publish()}
    ] do
      Beholder.post_proccessing(ppl)
    end

    {:ok, blocks} = PplBlocksQueries.get_all_by_id(ppl_id)
    assert Enum.all?(blocks, &(&1.terminate_request == "cancel"))

    assert_done_event_published(ppl_id)
  end

  test "a failed abort step is logged with the pipeline id" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        with_mocks [
          {PplBlocksQueries, [:passthrough],
           terminate_all: fn _ppl_id, _request, _desc -> {:error, :update_failed} end},
          {Looper.Publisher.AMQP, [], publish: capture_publish()}
        ] do
          Beholder.post_proccessing(ppl)
        end
      end)

    assert log =~ "terminate_ppl_blks failed for ppl_id: #{ppl.ppl_id}, error: :update_failed"
    assert_done_event_published(ppl.ppl_id)
  end

  test "a database error is logged by its code, without row data" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    error = %Postgrex.Error{
      postgres: %{code: :unique_violation, detail: "Key (owner)=(row-value) already exists."}
    }

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        with_mocks [
          {PplBlocksQueries, [:passthrough],
           terminate_all: fn _ppl_id, _request, _desc -> {:error, error} end},
          {Looper.Publisher.AMQP, [], publish: capture_publish()}
        ] do
          Beholder.post_proccessing(ppl)
        end
      end)

    assert log =~ "terminate_ppl_blks failed for ppl_id: #{ppl.ppl_id}"
    assert log =~ "Postgrex.Error unique_violation"
    refute log =~ "row-value"
  end

  test "an exit is logged by its tag, without the payload it carries" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    payload = {GenServer, :call, [self(), {:publish, %{url: "amqp://user:broker-password@host"}}]}

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        with_mock Looper.Publisher.AMQP, publish: fn _params -> exit({:timeout, payload}) end do
          Beholder.post_proccessing(ppl)
        end
      end)

    assert log =~ "publish_done failed for ppl_id: #{ppl.ppl_id}, exit: :timeout"
    refute log =~ "broker-password"
  end

  test "stuck abort requests a stop of an unfinished sub-init" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    with_mock Looper.Publisher.AMQP, publish: capture_publish() do
      Beholder.post_proccessing(ppl)
    end

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.terminate_request == "stop"
    assert psi.terminate_request_desc == "Pipeline terminated"
  end

  test "stuck abort sets the done_at timestamp" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, %{done_at: nil}} = PplTracesQueries.get_by_id(ppl_id)

    with_mock Looper.Publisher.AMQP, publish: capture_publish() do
      Beholder.post_proccessing(ppl)
    end

    assert {:ok, %{done_at: %DateTime{}}} = PplTracesQueries.get_by_id(ppl_id)
  end

  test "a user stop already recorded on the sub-init is kept" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    {:ok, _} = PplSubInitsQueries.terminate(psi, "stop", "API call")

    Beholder.terminate_sub_init(ppl)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.terminate_request == "stop"
    assert psi.terminate_request_desc == "API call"
  end

  @tag :integration
  test "a finished sub-init is left unchanged" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    create_blocks(ppl_id)
    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    {:ok, psi_before} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi_before.state == "done"

    Beholder.terminate_sub_init(ppl)

    assert {:ok, psi_before} == PplSubInitsQueries.get_by_id(ppl_id)
  end

  defp capture_publish do
    test_pid = self()

    fn params ->
      send(test_pid, {:published, params})
      :ok
    end
  end

  defp assert_done_event_published(ppl_id) do
    assert_received {:published, %{routing_key: "done", message: message}}
    assert PipelineEvent.decode(message).pipeline_id == ppl_id
  end

  defp create_blocks(ppl_id) do
    sub_init_loopers =
      [Task.Supervisor.start_link(name: PplsTaskSupervisor)]
      |> Test.Helpers.start_sub_init_loopers()

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
        __MODULE__,
        :do_wait_blocks_created,
        [ppl_id],
        10_000
      )

    Test.Helpers.stop_all_loopers(sub_init_loopers)
  end

  @tag :integration
  test "PplBlocks are terminated when ppl is stuck-aborted" do
    import Ecto.Query

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, _ppl} = Ppl.Ppls.Model.PplsQueries.get_by_id(ppl_id)

    create_blocks(ppl_id)

    Ppls
    |> where(ppl_id: ^ppl_id)
    |> update(set: [recovery_count: 100, in_scheduling: true])
    |> Repo.update_all([])

    assert {:ok, pid} = Beholder.start_link()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)

    loopers = Test.Helpers.start_all_loopers()

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
        __MODULE__,
        :do_wait_block_status,
        [
          ppl_id,
          %{
            "A" => [state: "done", result: "canceled"],
            "B" => [state: "done", result: "canceled"],
            "C" => [state: "done", result: "canceled"],
            "D" => [state: "done", result: "canceled"],
            "E" => [state: "done", result: "canceled"]
          }
        ],
        10_000
      )

    assert :ok = Beholder.stop(pid)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
  end

  def do_wait_blocks_created(ppl_id) do
    :timer.sleep(100)

    case PplBlocksQueries.get_all_by_id(ppl_id) do
      {:ok, blocks} -> blocks
      _ -> do_wait_blocks_created(ppl_id)
    end
  end

  def do_wait_block_status(ppl_id, desired_status) do
    :timer.sleep(100)
    {:ok, blocks} = PplBlocksQueries.get_all_by_id(ppl_id)

    if reached_desired_status?(blocks, desired_status) do
      blocks
    else
      do_wait_block_status(ppl_id, desired_status)
    end
  end

  defp reached_desired_status?(blocks, desired_status) do
    Enum.map(desired_status, fn {k, v} ->
      Enum.find_value(
        blocks,
        fn block ->
          block.name == k && block.state == Keyword.get(v, :state) &&
            block.result == Keyword.get(v, :result)
        end
      )
    end)
    |> Enum.all?(fn x -> x != nil end)
  end
end
