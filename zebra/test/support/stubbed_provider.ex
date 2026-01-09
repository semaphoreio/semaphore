defmodule Support.StubbedProvider do
  use FeatureProvider.Provider

  @e1_to_f1_org_id "org-e1-to-f1-enabled"
  @e2_to_f1_org_id "org-e2-to-f1-enabled"

  @impl FeatureProvider.Provider
  def provide_features(org_id \\ nil, _opts \\ []) do
    {:ok,
     [
       feature("max_paralellism_in_org", [:enabled, {:quantity, 500}]),
       feature("cache_cli_parallel_archive_method", [:hidden]),
       feature("some_custom_feature", [:hidden]),
       max_job_time_limit_feature(org_id),
       feature("e1_to_f1_migration", e1_to_f1_traits(org_id)),
       feature("e2_to_f1_migration", e2_to_f1_traits(org_id))
     ]}
  end

  def e1_to_f1_org_id, do: @e1_to_f1_org_id
  def e2_to_f1_org_id, do: @e2_to_f1_org_id

  defp max_job_time_limit_feature("enabled_30") do
    feature("max_job_execution_time_limit", [:enabled, {:quantity, 30}])
  end

  defp max_job_time_limit_feature("enabled_30_verified") do
    feature("max_job_execution_time_limit", [:enabled, {:quantity, 30}])
  end

  defp max_job_time_limit_feature("enabled_30_unverified") do
    feature("max_job_execution_time_limit", [:enabled, {:quantity, 30}])
  end

  defp max_job_time_limit_feature("enabled_48h") do
    feature("max_job_execution_time_limit", [:enabled, {:quantity, 48 * 60}])
  end

  defp max_job_time_limit_feature(_org_id) do
    feature("max_job_execution_time_limit", [:hidden])
  end

  defp e1_to_f1_traits(@e1_to_f1_org_id), do: [:enabled]
  defp e1_to_f1_traits(_org_id), do: [:hidden]

  defp e2_to_f1_traits(@e2_to_f1_org_id), do: [:enabled]
  defp e2_to_f1_traits(_org_id), do: [:hidden]

  @impl FeatureProvider.Provider
  def provide_machines(_org_id \\ nil, _opts \\ []) do
    {:ok,
     [
       # e1
       machine("e1-standard-2", [:linux, :enabled]),
       machine("e1-standard-4", [:linux, :enabled]),
       machine("e1-standard-8", [:linux, :enabled]),
       # a1
       machine("a1-standard-8", [:mac, :zero_state]),
       machine("a1-standard-4", [:mac, :enabled]),
       machine("ax1-standard-4", [:mac, :zero_state]),
       # c1
       machine("c1-standard-1", [:linux, :zero_state]),
       # e2
       machine("e2-standard-2", [:linux, :zero_state]),
       machine("e2-standard-4", [:linux, :zero_state]),
       # f1
       machine("f1-standard-2", [:linux, :zero_state]),
       machine("f1-standard-4", [:linux, :zero_state]),
       # g1
       machine("g1-standard-2", [:linux, :zero_state]),
       machine("g1-standard-3", [:linux, :hidden]),
       machine("g1-standard-4", [:linux, :zero_state])
     ]}
  end

  alias FeatureProvider.{Feature, Machine}

  def feature(type, traits) do
    traits
    |> Enum.reduce(
      %Feature{
        quantity: 0,
        state: :hidden,
        type: type
      },
      fn trait_name, feature ->
        trait(trait_name).(feature)
      end
    )
  end

  def machine(type, traits) do
    traits
    |> Enum.reduce(
      %Machine{
        quantity: 0,
        state: :hidden,
        type: type
      },
      fn trait_name, machine ->
        trait(trait_name).(machine)
      end
    )
  end

  defp trait(:linux) do
    fn
      %Machine{} = machine ->
        machine
        |> Map.put(:platform, "linux")
        |> Map.put(:available_os_images, ["ubuntu1804", "ubuntu2004", "ubuntu2204"])
        |> Map.put(:default_os_image, "ubuntu1804")

      other ->
        other
    end
  end

  defp trait(:mac) do
    fn
      %Machine{} = machine ->
        machine
        |> Map.put(:platform, "mac")
        |> Map.put(:available_os_images, ["macos-xcode13", "macos-xcode14"])
        |> Map.put(:default_os_image, "macos-xcode13")

      other ->
        other
    end
  end

  defp trait(:enabled) do
    fn thing ->
      thing
      |> Map.put(:state, :enabled)
      |> Map.put(:quantity, 1)
    end
  end

  defp trait(:zero_state) do
    fn thing ->
      thing
      |> Map.put(:state, :zero_state)
      |> Map.put(:quantity, 0)
    end
  end

  defp trait(:hidden) do
    fn thing ->
      thing
      |> Map.put(:state, :hidden)
      |> Map.put(:quantity, 0)
    end
  end

  defp trait({:quantity, quantity}) do
    fn thing ->
      thing
      |> Map.put(:quantity, quantity)
    end
  end

  defp trait(_), do: & &1
end
