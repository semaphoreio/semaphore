defmodule Ppl.OrgEventsConsumer.Test do
  use Ppl.IntegrationCase, async: false

  alias InternalApi.Organization.OrganizationBlocked
  alias Ppl.{Actions, OrgEventsConsumer}
  alias Util.Proto

  setup  do
    Test.Helpers.truncate_db()

    purge_queue("blocked")

    :ok
  end

  def purge_queue(queue) do
    {:ok, connection} = System.get_env("RABBITMQ_URL") |> AMQP.Connection.open()
    queue_name = "plumber.#{queue}"
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.declare(channel, queue_name, durable: true)

    AMQP.Queue.purge(channel, queue_name)

    AMQP.Connection.close(connection)
  end

  @tag :integration
  test "valid message received => all pipelines from the org are terminated" do
    loopers = Test.Helpers.start_all_loopers()

    ppls =
      1..5 |> Enum.map(fn _ ->
        assert {:ok, %{ppl_id: ppl_id}} =
          %{"repo_name" => "7_termination", "organization_id" => "miner_org",
            "label" => "master", "project_id" => "123"}
          |> Test.Helpers.schedule_request_factory(:local)
          |> Actions.schedule()

        ppl_id
      end)

    assert {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_basic"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl} =
      ppls |> Enum.at(0) |> Test.Helpers.wait_for_ppl_state("running", 3_000)

    event = Proto.deep_new!(OrganizationBlocked, %{org_id: "miner_org"})
    encoded = OrganizationBlocked.encode(event)

    assert {:ok, pid} = OrgEventsConsumer.start_link()

    Tackle.publish(encoded, exchange_params())

    assert_all_pipelines_from_org_stopped(ppls)

    # pipelines from other orgs are not affected
    assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 5_000)
    assert ppl.result == "passed"

    Test.Helpers.stop_all_loopers(loopers)
  end

  defp assert_all_pipelines_from_org_stopped(ppls) do
    Enum.map(ppls, fn ppl_id ->
      assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 11_000)
      assert ppl.result == "stopped" or ppl.result == "canceled"
      assert ppl.result_reason == "internal"
    end)
  end

  defp exchange_params() do
    %{url: System.get_env("RABBITMQ_URL"), exchange: "organization_exchange",
      routing_key: "blocked"}
  end
end
