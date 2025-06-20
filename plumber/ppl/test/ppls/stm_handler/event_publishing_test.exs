defmodule Ppl.Ppls.STMHandler.EventPublishing.Test do
  use Ppl.IntegrationCase

  alias Test.Helpers
  alias Ppl.Actions
  alias Ppl.Ppls.Model.PplsQueries
  alias InternalApi.Plumber.{ScheduleRequest, PipelineService}
  alias Ppl.Ppls.STMHandler.EventPublishing.Test.{
    RecordAgent,
    InitializingEventConsumer,
    PendingEventConsumer,
    QueuingEventConsumer,
    RunningEventConsumer,
    StoppingEventConsumer,
    DoneEventConsumer,
  }

  setup do
    Test.Helpers.truncate_db()

    ["initializing", "pending", "queuing", "running", "stopping", "done"]
    |> Enum.map(fn queue -> RecordAgent.purge_queue(queue) end)

    start_supervised!(RecordAgent)
    start_supervised!(InitializingEventConsumer)
    start_supervised!(PendingEventConsumer)
    start_supervised!(QueuingEventConsumer)
    start_supervised!(RunningEventConsumer)
    start_supervised!(StoppingEventConsumer)
    start_supervised!(DoneEventConsumer)

    Application.put_env(:ppl, :publish_retry_count, 3)

    :ok
  end

  @tag :integration
  test "all events are emitted for passed pipeline" do
   {:ok, %{ppl_id: ppl_id}} =
     %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml"}
     |> Test.Helpers.schedule_request_factory(:local)
     |> Actions.schedule()

    assert pipeline_passed(ppl_id)

    :timer.sleep(500)

    assert [init_e] = RecordAgent.get_messages("initializing")
    assert [pending_e] = RecordAgent.get_messages("pending")
    assert [running_e] = RecordAgent.get_messages("running")
    assert [done_e] = RecordAgent.get_messages("done")

    assert ppl_id == init_e.pipeline_id
    assert init_e.pipeline_id == pending_e.pipeline_id
    assert pending_e.pipeline_id == running_e.pipeline_id
    assert running_e.pipeline_id == done_e.pipeline_id

    init_ts = to_date_time(init_e.timestamp)
    pending_ts = to_date_time(pending_e.timestamp)
    running_ts = to_date_time(running_e.timestamp)
    done_ts = to_date_time(done_e.timestamp)

    assert DateTime.compare(init_ts, pending_ts) == :lt
    assert DateTime.compare(pending_ts, running_ts) == :lt
    assert DateTime.compare(running_ts, done_ts) == :lt

    assert RecordAgent.get_messages("stopping") == []

    Application.put_env(:ppl, :publish_retry_count, 1)
  end

  defp to_date_time(timestamp) do
    ts_in_microseconds = timestamp.seconds * 1_000_000 + Integer.floor_div(timestamp.nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  defp pipeline_passed(ppl_id) do
    loopers = Test.Helpers.start_all_loopers()
    args = [ppl_id, loopers]

    Helpers.assert_finished_for_less_than(__MODULE__, :ppl_execution_done?, args, 30_000)
  end

  def ppl_execution_done?(ppl_id, loopers) do
    :timer.sleep 1_000

    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    ppl_execution_done_(ppl.state, ppl.result, ppl_id, loopers)
  end

  defp ppl_execution_done_("done", "passed", _ppl_id, loopers) do
      Test.Helpers.stop_all_loopers(loopers)
      :pass
  end
  defp ppl_execution_done_(_state, _, ppl_id, loopers),
    do: ppl_execution_done?(ppl_id, loopers)
end

defmodule Ppl.Ppls.STMHandler.EventPublishing.Test.RecordAgent do
  @moduledoc false

  use Agent

  def start_link(_) do
    Agent.start_link(fn ->
      ["initializing", "pending", "queuing", "running", "stopping", "done"]
      |> Enum.reduce(%{}, fn key, map -> Map.put(map, key, []) end)
     end, name: __MODULE__)
  end

  def get_messages(type) do
    Agent.get(__MODULE__, &Map.get(&1, type, []))
  end

  def save(message, type) do
    Agent.update(__MODULE__, fn agent_state ->
      agent_state |> Map.update!(type, fn list -> list ++ [message] end)
    end)
  end

  def purge_queue(queue) do
    {:ok, connection} = System.get_env("RABBITMQ_URL") |> AMQP.Connection.open()
    queue_name = "test.#{queue}"
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.declare(channel, queue_name, durable: true)

    AMQP.Queue.purge(channel, queue_name)

    AMQP.Connection.close(connection)
  end
end

defmodule Ppl.Ppls.STMHandler.EventPublishing.Test.InitializingEventConsumer do
  @moduledoc false

  alias InternalApi.Plumber.PipelineEvent
  alias InternalApi.Plumber.Pipeline.State
  alias Ppl.Ppls.STMHandler.EventPublishing.Test.RecordAgent

  use Tackle.Consumer,
    url: url(),
    exchange: "pipeline_state_exchange",
    routing_key: "initializing",
    service: "test"

  def url(), do: System.get_env("RABBITMQ_URL")

  def handle_message(message) do
    event = message |> PipelineEvent.decode()
    event |> RecordAgent.save(event.state |> from_proto())
  end

  def start_link(_), do: start_link()

  defp from_proto(state),
    do: state |> State.key() |> Atom.to_string() |> String.downcase()
end

defmodule Ppl.Ppls.STMHandler.EventPublishing.Test.PendingEventConsumer do
  @moduledoc false

  alias InternalApi.Plumber.PipelineEvent
  alias InternalApi.Plumber.Pipeline.State
  alias Ppl.Ppls.STMHandler.EventPublishing.Test.RecordAgent

  use Tackle.Consumer,
    url: url(),
    exchange: "pipeline_state_exchange",
    routing_key: "pending",
    service: "test"

  def url(), do: System.get_env("RABBITMQ_URL")

  def handle_message(message) do
    event = message |> PipelineEvent.decode()
    event |> RecordAgent.save(event.state |> from_proto())
  end

  def start_link(_), do: start_link()

  defp from_proto(state),
    do: state |> State.key() |> Atom.to_string() |> String.downcase()
end

defmodule Ppl.Ppls.STMHandler.EventPublishing.Test.QueuingEventConsumer do
  @moduledoc false

  alias InternalApi.Plumber.PipelineEvent
  alias InternalApi.Plumber.Pipeline.State
  alias Ppl.Ppls.STMHandler.EventPublishing.Test.RecordAgent

  use Tackle.Consumer,
    url: url(),
    exchange: "pipeline_state_exchange",
    routing_key: "queuing",
    service: "test"

  def url(), do: System.get_env("RABBITMQ_URL")

  def handle_message(message) do
    event = message |> PipelineEvent.decode()
    event |> RecordAgent.save(event.state |> from_proto())
  end

  def start_link(_), do: start_link()

  defp from_proto(state),
    do: state |> State.key() |> Atom.to_string() |> String.downcase()
end

defmodule Ppl.Ppls.STMHandler.EventPublishing.Test.RunningEventConsumer do
  @moduledoc false

  alias InternalApi.Plumber.PipelineEvent
  alias InternalApi.Plumber.Pipeline.State
  alias Ppl.Ppls.STMHandler.EventPublishing.Test.RecordAgent

  use Tackle.Consumer,
    url: url(),
    exchange: "pipeline_state_exchange",
    routing_key: "running",
    service: "test"

  def url(), do: System.get_env("RABBITMQ_URL")

  def handle_message(message) do
    event = message |> PipelineEvent.decode()
    event |> RecordAgent.save(event.state |> from_proto())
  end

  def start_link(_), do: start_link()

  defp from_proto(state),
    do: state |> State.key() |> Atom.to_string() |> String.downcase()
end

defmodule Ppl.Ppls.STMHandler.EventPublishing.Test.StoppingEventConsumer do
  @moduledoc false

  alias InternalApi.Plumber.PipelineEvent
  alias InternalApi.Plumber.Pipeline.State
  alias Ppl.Ppls.STMHandler.EventPublishing.Test.RecordAgent

  use Tackle.Consumer,
    url: url(),
    exchange: "pipeline_state_exchange",
    routing_key: "stopping",
    service: "test"

  def url(), do: System.get_env("RABBITMQ_URL")

  def handle_message(message) do
    event = message |> PipelineEvent.decode()
    event |> RecordAgent.save(event.state |> from_proto())
  end

  def start_link(_), do: start_link()

  defp from_proto(state),
    do: state |> State.key() |> Atom.to_string() |> String.downcase()
end

defmodule Ppl.Ppls.STMHandler.EventPublishing.Test.DoneEventConsumer do
  @moduledoc false

  alias InternalApi.Plumber.PipelineEvent
  alias InternalApi.Plumber.Pipeline.State
  alias Ppl.Ppls.STMHandler.EventPublishing.Test.RecordAgent

  use Tackle.Consumer,
    url: url(),
    exchange: "pipeline_state_exchange",
    routing_key: "done",
    service: "test"

  def url(), do: System.get_env("RABBITMQ_URL")

  def handle_message(message) do
    event = message |> PipelineEvent.decode()
    event |> RecordAgent.save(event.state |> from_proto())
  end

  def start_link(_), do: start_link()

  defp from_proto(state),
    do: state |> State.key() |> Atom.to_string() |> String.downcase()
end
