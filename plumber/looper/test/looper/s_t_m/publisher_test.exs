defmodule Looper.STM.Publisher.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Looper.STM.Test.Items
  alias Looper.Test.EctoRepo

  defmodule RunPublisherInEpilogue do
    @moduledoc false

    use Looper.STM,
      id: __MODULE__,
      period_ms: 30,
      repo: EctoRepo,
      schema: Items,
      observed_state: "initializing",
      allowed_states: ~w(running done),
      cooling_time_sec: 0,
      columns_to_log: [:state, :recovery_count],
      publisher_cb: fn parmas -> apply(__MODULE__, :publisher_cb_impl, [parmas]) end

    def initial_query(), do: Items

    def terminate_request_handler(_tr, _event), do: {:ok, :continue}

    def scheduling_handler(_), do: {:ok, fn _repo, _ -> {:ok, %{state: "running"}} end}

    def epilogue_handler({:ok, %{:exit_transition => item}}) do
      from(p in Items, where: p.id == ^item.id)
      |> EctoRepo.update_all(set: [description: %{"epilogue" => "executed"},
                                   updated_at: NaiveDateTime.utc_now()])
    end

    def publisher_cb_impl(params) do
      with ts_string       <- params.timestamp |> DateTime.to_iso8601(),
           params          <- Map.put(params, :timestamp, ts_string),
           encoded_event   <- "#{inspect params}",
           exchange_params <- %{url: System.get_env("RABBITMQ_URL"),
                                exchange: "default_exchange",
                                routing_key: params.state}

      do
        {:ok, encoded_event, exchange_params}
      end
    end
  end

  defmodule RecordAgent do
    @moduledoc false

    use Agent

    def start_link(_) do
      Agent.start_link(fn -> %{"running" => []} end, name: __MODULE__)
    end

    def get_messages(type) do
      Agent.get(__MODULE__, &Map.get(&1, type, []))
    end

    def save(message, type) do
      Agent.update(__MODULE__, fn state ->
        state |> Map.update!(type, fn list -> list ++ [message] end)
      end)
    end

    def purge_queue(url, queue) do
      {:ok, connection} = url |> AMQP.Connection.open()
      queue_name = "test.#{queue}"
      {:ok, channel} = AMQP.Channel.open(connection)

      AMQP.Queue.declare(channel, queue_name, durable: true)

      AMQP.Queue.purge(channel, queue_name)

      AMQP.Connection.close(connection)
    end
  end

  defmodule EventConsumer do
    @moduledoc false

    use Tackle.Consumer,
      url: System.get_env("RABBITMQ_URL"),
      exchange: "default_exchange",
      routing_key: "running",
      service: "test"

    def handle_message(message) do
      event =  message |> Code.eval_string() |> elem(0)
      {:ok, timestamp, _} = event.timestamp |> DateTime.from_iso8601()
      Map.put(event, :timestamp, timestamp) |> RecordAgent.save("running")
    end
  end

  test "STM runs Publisher in epilogue before user commands" do
    EctoRepo.delete_all Items

    id_1 = UUID.uuid4()
    id_2 = UUID.uuid4()

    {:ok, %{:id => id, :description => description}} =
      %Items{state: "initializing", some_id: id_1, some_other_id: id_2}
      |> EctoRepo.insert

    assert description == nil

    amqp_url = System.get_env("RABBITMQ_URL")
    {:ok, _publisher} = Looper.Publisher.AMQP.start_link(amqp_url)

    RecordAgent.start_link(:asdf)
    RecordAgent.purge_queue(amqp_url, "running")
    {:ok, consumer} = EventConsumer.start_link()
    Looper.STM.Publisher.Test.RunPublisherInEpilogue.start_link()

    assert {:ok, timestamp} = event_published?(id_1, id_2, 0)

    Looper.STM.Publisher.Test.RunPublisherInEpilogue.stop()
    Looper.Publisher.AMQP.stop()
    GenServer.stop(consumer)

    %{:description => description, updated_at: updated_at} =
      from(p in Items, where: p.id == ^id)
      |> EctoRepo.one()

    assert description == %{"epilogue" => "executed"}
    assert NaiveDateTime.compare(updated_at, DateTime.to_naive(timestamp)) == :gt
  end

  def event_published?(expected_id_1, expected_id_2, count) do
    :timer.sleep 100

    events = RecordAgent.get_messages("running")
    if length(events) == 1 do
      event = Enum.at(events, 0)
      assert event.some_id == expected_id_1
      assert event.some_other_id == expected_id_2
      assert event.state == "running"

      {:ok, event.timestamp}
    else
      if count < 50 do
        event_published?(expected_id_1, expected_id_2, count + 1)
      else
        {:error, "event_published? check count exceded"}
      end
    end
  end
end
