defmodule Projecthub.Workers.AgentStoreTest do
  use ExUnit.Case
  doctest Projecthub.Workers.AgentStore
  alias Projecthub.Workers.AgentStore

  setup do
    existing_key = Ecto.UUID.generate()
    non_existing_key = Ecto.UUID.generate()

    initial_state = %{
      existing_key => {1, DateTime.utc_now()}
    }

    start_supervised({Projecthub.Workers.AgentStore, name: __MODULE__, initial_state: initial_state})

    %{
      existing_key: existing_key,
      non_existing_key: non_existing_key
    }
  end

  describe "get/3" do
    test "returns :not_found when there are no agents in cache", %{non_existing_key: non_existing_key} do
      assert :not_found == AgentStore.get(__MODULE__, non_existing_key)
    end

    test "returns expired result if it exists", %{existing_key: existing_key} do
      assert {:expired, 1} == AgentStore.get(__MODULE__, existing_key, item_ttl_ms: :timer.seconds(0))
    end

    test "returns result if it exists", %{existing_key: existing_key} do
      assert 1 == AgentStore.get(__MODULE__, existing_key)
    end
  end

  describe "store/3" do
    test "stores data under the key" do
      assert :not_found == AgentStore.get(__MODULE__, "key")
      assert 1 == AgentStore.store(__MODULE__, "key", 1)
      assert 1 == AgentStore.get(__MODULE__, "key")
    end

    test "stores data under the key with ttl" do
      assert :not_found == AgentStore.get(__MODULE__, "key")
      assert 1 == AgentStore.store(__MODULE__, "key", 1)
      assert 1 == AgentStore.get(__MODULE__, "key")
      :timer.sleep(150)
      assert {:expired, 1} == AgentStore.get(__MODULE__, "key", item_ttl_ms: 100)
    end
  end
end
