defmodule Projecthub.Events.ProjectRestoredTest do
  use Projecthub.DataCase
  alias Projecthub.Events.ProjectRestored

  describe ".publish" do
    test "returns once the broker has the event" do
      {:ok, project} = Support.Factories.Project.create()

      {:ok, connection} = AMQP.Connection.open(Application.fetch_env!(:projecthub, :amqp_url))
      on_exit(fn -> AMQP.Connection.close(connection) end)

      {:ok, channel} = AMQP.Channel.open(connection)
      :ok = AMQP.Exchange.direct(channel, "project_exchange", durable: true)
      {:ok, %{queue: queue}} = AMQP.Queue.declare(channel, "", exclusive: true)
      :ok = AMQP.Queue.bind(channel, queue, "project_exchange", routing_key: "restored")

      assert {:ok, nil} = ProjectRestored.publish(project)

      assert {:ok, payload, _meta} = AMQP.Basic.get(channel, queue, no_ack: true)
      assert InternalApi.Projecthub.ProjectRestored.decode(payload).project_id == project.id
    end

    test "raises when the broker cannot be reached" do
      {:ok, project} = Support.Factories.Project.create()

      url = Application.fetch_env!(:projecthub, :amqp_url)
      Application.put_env(:projecthub, :amqp_url, "amqp://127.0.0.1:1")
      on_exit(fn -> Application.put_env(:projecthub, :amqp_url, url) end)

      assert_raise MatchError, fn -> ProjectRestored.publish(project) end
    end
  end
end
