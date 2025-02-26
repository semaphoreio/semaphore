defmodule FeatureFactory do
  @moduledoc false
  @feature_keys Map.keys(%FeatureProvider.Feature{})
  @machine_keys Map.keys(%FeatureProvider.Machine{})

  def build_features(feature_list) do
    Enum.map(feature_list, &build_feature/1)
  end

  def build_feature(params) when is_map(params) do
    feature = build_feature(nil)

    params
    |> Enum.reduce(feature, fn
      {key, value}, acc when key in @feature_keys ->
        Map.put(acc, key, value)

      _, acc ->
        acc
    end)
  end

  def build_feature(type) do
    %FeatureProvider.Feature{
      name: "#{type}",
      type: type,
      description: "",
      quantity: 1,
      state: :enabled
    }
  end

  def build_machines(machine_list) do
    Enum.map(machine_list, &build_machine/1)
  end

  def build_machine(params) when is_map(params) do
    machine = build_machine(nil)

    params
    |> Enum.reduce(machine, fn
      {key, value}, acc when key in @machine_keys ->
        Map.put(acc, key, value)

      _, acc ->
        acc
    end)
  end

  def build_machine(type) do
    %FeatureProvider.Machine{
      type: type,
      platform: "",
      vcpu: "",
      ram: "",
      disk: "",
      default_os_image: "",
      available_os_images: ["", ""],
      quantity: 1,
      state: :enabled
    }
  end

  def stub_provider(provider) do
    import Mox

    provider
    |> stub(:provide_features, fn _args, _opts ->
      {:ok,
       FeatureFactory.build_features([
         "enabled_feature",
         %{type: "hidden_feature", state: :hidden, quantity: 0},
         %{type: "zero_state_feature", state: :zero_state, quantity: 50}
       ])}
    end)
    |> stub(:provide_machines, fn _args, _opts ->
      {:ok,
       FeatureFactory.build_machines([
         %{type: "t1-test-2", state: :enabled, quantity: 10, platform: "linux"},
         %{type: "t1-test-4", state: :enabled, quantity: 5, platform: "linux"},
         %{type: "tx1-test-2", state: :zero_state, quantity: 1, platform: "linux"},
         %{type: "ax1-test-2", state: :hidden, quantity: 0, platform: "mac"}
       ])}
    end)
  end
end
