defmodule Rbac.EventsTest do
  use ExUnit.Case
  doctest Rbac.Events
  alias Rbac.Events

  import Ecto.UUID, only: [generate: 0]

  describe "publish" do
    test "validates routing keys" do
      assert(:error = Events.publish("test", generate(), generate(), generate()))
      assert(:error = Events.publish("foo", generate(), generate(), generate()))
      assert(:error = Events.publish("bar", generate(), generate(), generate()))
    end

    test "sends messages to the queue" do
      org_id = generate()
      user_id = generate()
      project_id = generate()

      {:module, consumer, _, _} =
        Support.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:rbac, :amqp_url),
          "rbac_exchange",
          "role_assigned",
          Ecto.UUID.generate(),
          :role_assigned
        )

      {:ok, _} = consumer.start_link()

      :ok = Events.publish("role_assigned", user_id, org_id, project_id)
      assert_receive {:ok, :role_assigned}, 5_000
    end
  end
end
