defmodule Ppl.Ppls.STMHandler.Queuing.Test do
  use Ppl.IntegrationCase

  alias Ppl.Ppls.Model.{PplsQueries, Ppls}
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.STMHandler.Queuing.Test.RunningStateTestLooper
  alias Ppl.Ppls.STMHandler.{PendingState, QueuingState}
  alias Test.Helpers
  alias Ppl.EctoRepo, as: Repo

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  test "pipelines from same branch but different projects are not queuing" do
    ppl_1 = create_ppl(1, "123") |> to_state("pending")
    ppl_2 = create_ppl(2, "456") |> to_state("pending")

    {:ok, pid} =  PendingState.start_link()
    {:ok, pid_2} =  QueuingState.start_link()

    :timer.sleep(3_000)

    GenServer.stop(pid)
    GenServer.stop(pid_2)

    assert {:ok, result} = PplsQueries.get_by_id(ppl_1.ppl_id)
    assert result.state == "running"

    assert {:ok, result} = PplsQueries.get_by_id(ppl_2.ppl_id)
    assert result.state == "running"
  end

  @num_of_events 30
  @num_of_loopers_sets 3
  @test_timeout_ms 50_000

  @doc """
  Test does the following:
  It creates 'num_of_events' pipeline requests from same repo and branch, then
  it starts 'num_of_loopers_sets' sets of Pending, Queuing and MockedRunning State
  loopers and starts to transfer pipelines to pending state in random order.
  MockedRunningState looper immidietly transfers each event from running to done
  state and stores time of transition for that pipeline in ResultAgent.
  Once all pipelines are transfered to pending state, test waits until all pipelines
  are transfered to done state by loopers or timeouts when 'test_timeout_ms' miliseconds
  is reached. If all pipelines are in done state, test then  checks if they
  arrived there in right order by comparing times for each pipeline in ResultAgent.
  """
  test "#{@num_of_events} ppls from same branch are scheduled in right order" do
    ppls = Enum.map(Range.new(0, @num_of_events), &(create_ppl(&1)))

    loopers = Enum.flat_map(Range.new(1, @num_of_loopers_sets), &(start_loopers(&1)))

    assert :pass = random_transitions_to_queuing(ppls, @num_of_events)

    youngest_ppl = Enum.at(ppls, @num_of_events)
    Helpers.assert_finished_for_less_than(__MODULE__, :all_done, [youngest_ppl], @test_timeout_ms)

    Enum.map(Range.new(0, @num_of_events), fn index -> compare_times(ppls, index) end)

    stop_loopers(loopers)
  end

  def create_ppl(index, queue_id \\ "123") do
    request = Test.Helpers.schedule_request_factory(%{"project_id" => queue_id}, :local)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"jobs" => jobs_list, "agent" => agent}
    definition = %{"version" => "v1.0", "agent" => agent,
      "name" => "#{index}", "blocks" => [%{"name" => "Blk 0", "build" => build},
                                        %{"name" => "Blk 1", "build" => build}]}

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)
    {:ok, ppl} = ppl_req |> Map.from_struct()  |> PplsQueries.insert()

    {:ok, ppl} = ppl |> Ppls.changeset(%{queue_id: queue_id}) |> Repo.update()

    assert ppl.state == "initializing"
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ppl)

    ppl = ppl |> to_state("pending")
    PplTracesQueries.set_timestamp(ppl.ppl_id, :pending_at)
    ppl
  end

  def start_loopers(index) do
    {:ok, pid1} = "queuing-#{index}" |> String.to_atom() |> QueuingState.start_link()
    {:ok, pid2} = "running-mock-#{index}" |> String.to_atom() |> RunningStateTestLooper.start_link()
    [pid1, pid2]
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(&(GenServer.stop(&1)))
  end

  defp random_transitions_to_queuing(ppls, len) when len >= 0 do
    200 |> :rand.uniform() |> :timer.sleep()

    index = :rand.uniform(len + 1) -1
    ppl = ppls |> Enum.at(index) |> to_state("queuing")
    PplTracesQueries.set_timestamp(ppl.ppl_id, :queuing_at)
    ppls |> List.delete(ppl) |> random_transitions_to_queuing(len - 1)
  end
  defp random_transitions_to_queuing(_, _), do: :pass

  def query_params() do
    %{initial_query: Ppl.Ppls.Model.Ppls, cooling_time_sec: -2,
      repo: Ppl.EctoRepo, schema: Ppl.Ppls.Model.Ppls, returning: [:id, :ppl_id],
      allowed_states: ~w(initializing pending queuing running stopping done)}
  end

  def to_state(ppl, state) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(ppl, fn _, _ -> {:ok, %{state: state}} end, args)
    ppl
  end

  def all_done(youngest_ppl) do
    :timer.sleep(500)

    assert {:ok, ppl} = PplsQueries.get_by_id(youngest_ppl.ppl_id)
    assert {:ok, list} = PplsQueries.ppls_from_same_queue_in_states(ppl, ["done"])
    IO.inspect(length(list), label: "\nPipelines in done: ")
    all_done_(youngest_ppl, ppl.state, length(list))
  end

  defp all_done_(_, "done", @num_of_events) do
    :pass
  end
  defp all_done_(youngest_ppl, _, _), do: all_done(youngest_ppl)

  def compare_times(_ppls, 0), do: true
  def compare_times(ppls, index) do
    {:ok, current_trace} = get_trace(ppls, index)
    {:ok, previous_trace} = get_trace(ppls, index - 1)

    assert_timestamps_set_correctly(current_trace)
    assert DateTime.compare(previous_trace.done_at, current_trace.running_at) == :lt
  end

  defp get_trace(ppls, index) do
    ppls|> Enum.at(index) |> Map.get(:ppl_id) |> PplTracesQueries.get_by_id()
  end

  defp assert_timestamps_set_correctly(ppl_trace) do
    assert DateTime.compare(ppl_trace.created_at, ppl_trace.pending_at) == :lt
    assert DateTime.compare(ppl_trace.pending_at, ppl_trace.queuing_at) == :lt
    assert DateTime.compare(ppl_trace.queuing_at, ppl_trace.running_at) == :lt
    assert DateTime.compare(ppl_trace.running_at, ppl_trace.done_at) == :lt
    assert ppl_trace.stopping_at |> is_nil()
  end
end

defmodule Ppl.Ppls.STMHandler.Queuing.Test.RunningStateTestLooper do

  alias Ppl.Ppls.Model.Ppls
  alias Ppl.PplTraces.Model.PplTracesQueries

  use Looper.STM,
    id: __MODULE__,
    period_ms: 100,
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    observed_state: "running",
    allowed_states: ~w(done),
    cooling_time_sec: 0,
    columns_to_log: [:state, :recovery_count, :ppl_id]

    def initial_query(), do: Ppls

    def terminate_request_handler(_ppl, _), do: {:ok, :continue}

    def scheduling_handler(ppl) do
      PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
      {:ok, fn _, _ -> {:ok, %{state: "done", result: "passed"}} end}
    end

    def epilogue_handler({:ok, _}), do: Ppl.Ppls.STMHandler.QueuingState.execute_now()
end
