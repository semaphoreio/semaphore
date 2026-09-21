defmodule Front.FeatureHubProviderTest do
  use Front.TestCase, async: false

  alias Front.FeatureHubProvider
  alias Support.Stubs.Feature, as: FeatureStub

  @org_id "org-id-123"

  describe "provide_features/2" do
    test "with nil org_id returns global features" do
      FeatureStub.setup_feature("test_feature", state: :ENABLED, quantity: 5)

      {:ok, features} = FeatureHubProvider.provide_features(nil)

      feature = Enum.find(features, &(&1.type == "test_feature"))
      assert feature
      assert feature.state == :enabled
      assert feature.quantity == 5
    end

    test "with org_id returns organization features" do
      FeatureStub.setup_feature("test_feature", state: :ENABLED, quantity: 5)
      FeatureStub.set_org_defaults(@org_id)
      FeatureStub.enable_feature(@org_id, "test_feature")

      {:ok, features} = FeatureHubProvider.provide_features(@org_id)

      feature = Enum.find(features, &(&1.type == "test_feature"))
      assert feature
      assert feature.state == :enabled
    end

    test "with nil org_id filters out hidden features" do
      FeatureStub.setup_feature("hidden_feature", state: :HIDDEN, quantity: 0)

      {:ok, features} = FeatureHubProvider.provide_features(nil)

      refute Enum.any?(features, &(&1.type == "hidden_feature"))
    end

    test "with org_id filters out hidden features" do
      FeatureStub.setup_feature("hidden_feature", state: :HIDDEN, quantity: 0)
      FeatureStub.set_org_defaults(@org_id)

      {:ok, features} = FeatureHubProvider.provide_features(@org_id)

      refute Enum.any?(features, &(&1.type == "hidden_feature"))
    end

    test "with nil org_id includes zero_state features" do
      FeatureStub.setup_feature("zero_feature", state: :ZERO_STATE, quantity: 1)

      {:ok, features} = FeatureHubProvider.provide_features(nil)

      feature = Enum.find(features, &(&1.type == "zero_feature"))
      assert feature
      assert feature.state == :zero_state
    end

    test "with org_id includes zero_state features" do
      FeatureStub.setup_feature("zero_feature", state: :ZERO_STATE, quantity: 1)
      FeatureStub.set_org_defaults(@org_id)
      FeatureStub.zero_feature(@org_id, "zero_feature")

      {:ok, features} = FeatureHubProvider.provide_features(@org_id)

      feature = Enum.find(features, &(&1.type == "zero_feature"))
      assert feature
      assert feature.state == :zero_state
    end
  end

  describe "provide_machines/2" do
    setup do
      FeatureStub.setup_machine("e1-standard-2",
        platform: :linux,
        vcpu: "2",
        ram: "4",
        disk: "25",
        state: :ENABLED,
        quantity: 8
      )

      FeatureStub.setup_machine("a1-standard-4",
        platform: :mac,
        vcpu: "4",
        ram: "8",
        disk: "50",
        state: :ENABLED,
        quantity: 2
      )

      :ok
    end

    test "with nil org_id returns global machines" do
      {:ok, machines} = FeatureHubProvider.provide_machines(nil)

      machine = Enum.find(machines, &(&1.type == "e1-standard-2"))
      assert machine
      assert machine.state == :enabled
      assert machine.quantity == 8
      assert machine.vcpu == "2"
      assert machine.ram == "4"
      assert machine.platform == "LINUX"
    end

    test "with org_id returns organization machines" do
      FeatureStub.set_org_defaults(@org_id)

      {:ok, machines} = FeatureHubProvider.provide_machines(@org_id)

      machine = Enum.find(machines, &(&1.type == "e1-standard-2"))
      assert machine
      assert machine.state == :enabled
      assert machine.quantity == 8
    end

    test "with nil org_id filters out hidden machines" do
      FeatureStub.setup_machine("hidden-machine", state: :HIDDEN, quantity: 0)

      {:ok, machines} = FeatureHubProvider.provide_machines(nil)

      refute Enum.any?(machines, &(&1.type == "hidden-machine"))
    end

    test "with org_id filters out hidden machines" do
      FeatureStub.setup_machine("hidden-machine", state: :HIDDEN, quantity: 0)
      FeatureStub.set_org_defaults(@org_id)

      {:ok, machines} = FeatureHubProvider.provide_machines(@org_id)

      refute Enum.any?(machines, &(&1.type == "hidden-machine"))
    end

    test "with nil org_id orders machines by type" do
      {:ok, machines} = FeatureHubProvider.provide_machines(nil)

      types = Enum.map(machines, & &1.type)
      assert types == Enum.sort(types)
    end

    test "with org_id orders machines by type" do
      FeatureStub.set_org_defaults(@org_id)

      {:ok, machines} = FeatureHubProvider.provide_machines(@org_id)

      types = Enum.map(machines, & &1.type)
      assert types == Enum.sort(types)
    end

    test "with nil org_id maps machine fields correctly" do
      {:ok, machines} = FeatureHubProvider.provide_machines(nil)

      machine = Enum.find(machines, &(&1.type == "a1-standard-4"))
      assert machine
      assert machine.platform == "MAC"
      assert machine.vcpu == "4"
      assert machine.ram == "8"
      assert machine.disk == "50"
    end
  end
end
