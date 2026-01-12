defmodule Zebra.Workers.FeatureProviderInvalidatorWorkerTest do
  use ExUnit.Case

  alias Zebra.FeatureProviderInvalidatorWorker, as: Worker

  import Mox
  setup :verify_on_exit!

  describe ".machines_changed" do
    setup do
      provider = Application.get_env(FeatureProvider, :provider)
      on_exit(fn -> Application.put_env(FeatureProvider, :provider, provider) end)

      start_supervised!({Cachex, name: :feature_invalidator_cache})

      Application.put_env(
        FeatureProvider,
        :provider,
        {Support.MockedProvider,
         [cache: {FeatureProvider.CachexCache, name: :feature_invalidator_cache}]}
      )
    end

    test "when the machine state changes, machine caches are invalidated" do
      alias InternalApi.Feature.MachinesChanged

      Support.MockedProvider
      |> expect(:provide_machines, fn _, _ ->
        {:ok, []}
      end)

      {:ok, machines} = FeatureProvider.list_machines()
      assert machines == []

      {:ok, machines} = FeatureProvider.list_machines()
      assert machines == []

      Support.MockedProvider
      |> expect(:provide_machines, fn param, opts ->
        Support.StubbedProvider.provide_machines(param, opts)
      end)

      callback_message = %MachinesChanged{} |> MachinesChanged.encode()

      Worker.machines_changed(callback_message)

      {:ok, machines} = FeatureProvider.list_machines()
      assert length(machines) == 14
    end

    test "when the organization machine state changes, organization machine caches are invalidated" do
      alias InternalApi.Feature.OrganizationMachinesChanged

      Support.MockedProvider
      |> expect(:provide_machines, fn "org-1", _opts ->
        {:ok, []}
      end)

      assert {:ok, machines} = FeatureProvider.list_machines(param: "org-1")
      assert machines == []
      assert {:ok, machines} = FeatureProvider.list_machines(param: "org-1")
      assert machines == []

      Support.MockedProvider
      |> expect(:provide_machines, fn "org-1", _ ->
        {:ok, [Support.StubbedProvider.machine("some-machine", [])]}
      end)

      callback_message =
        %OrganizationMachinesChanged{org_id: "org-1"} |> OrganizationMachinesChanged.encode()

      Worker.organization_machines_changed(callback_message)

      {:ok, machines} = FeatureProvider.list_machines(param: "org-1")
      assert length(machines) == 1
    end

    test "when the feature state changes, feature caches are invalidated" do
      alias InternalApi.Feature.FeaturesChanged

      Support.MockedProvider
      |> expect(:provide_features, fn _, _ ->
        {:ok, []}
      end)

      {:ok, features} = FeatureProvider.list_features()
      assert features == []

      {:ok, features} = FeatureProvider.list_features()
      assert features == []

      Support.MockedProvider
      |> expect(:provide_features, fn param, opts ->
        Support.StubbedProvider.provide_features(param, opts)
      end)

      callback_message = %FeaturesChanged{} |> FeaturesChanged.encode()

      Worker.features_changed(callback_message)

      {:ok, features} = FeatureProvider.list_features()
      assert length(features) == 7
    end

    test "when the organization feature state changes, organization feature caches are invalidated" do
      alias InternalApi.Feature.OrganizationFeaturesChanged

      Support.MockedProvider
      |> expect(:provide_features, fn "org-1", _opts ->
        {:ok, []}
      end)

      assert {:ok, features} = FeatureProvider.list_features(param: "org-1")
      assert features == []
      assert {:ok, features} = FeatureProvider.list_features(param: "org-1")
      assert features == []

      Support.MockedProvider
      |> expect(:provide_features, fn "org-1", _ ->
        {:ok, [Support.StubbedProvider.feature("some-feature", [])]}
      end)

      callback_message =
        %OrganizationFeaturesChanged{org_id: "org-1"} |> OrganizationFeaturesChanged.encode()

      Worker.organization_features_changed(callback_message)

      {:ok, features} = FeatureProvider.list_features(param: "org-1")
      assert length(features) == 1
    end
  end
end
