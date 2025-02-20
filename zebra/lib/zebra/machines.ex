defmodule Zebra.Machines do
  require Logger
  @linux "linux"
  @mac "mac"

  def machines do
    FeatureProvider.list_machines()
    |> case do
      {:ok, machines} ->
        machines

      _ ->
        []
    end
  end

  def machines(org_id) do
    FeatureProvider.list_machines(param: org_id)
    |> case do
      {:ok, machines} ->
        machines

      _ ->
        []
    end
  end

  def linux, do: @linux
  def mac, do: @mac

  def machine_types do
    machines()
    |> Enum.map(fn m -> m.type end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def machine_types(org_id) do
    machines(org_id)
    |> Enum.map(& &1.type)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def linux_machine_types do
    machines()
    |> Enum.filter(&FeatureProvider.Machine.linux?/1)
    |> Enum.map(fn m -> m.type end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def linux_machine_types(org_id) do
    machines(org_id)
    |> Enum.filter(&FeatureProvider.Machine.linux?/1)
    |> Enum.map(fn m -> m.type end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def mac_machine_types do
    machines()
    |> Enum.filter(&FeatureProvider.Machine.mac?/1)
    |> Enum.map(fn m -> m.type end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def mac_machine_types(org_id) do
    machines(org_id)
    |> Enum.filter(&FeatureProvider.Machine.mac?/1)
    |> Enum.map(fn m -> m.type end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def os_images do
    machines()
    |> Enum.flat_map(fn m -> m.available_os_images end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def os_images(org_id) do
    machines(org_id)
    |> Enum.flat_map(fn m -> m.available_os_images end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def spec(machine = %FeatureProvider.Machine{}) do
    "#{machine.vcpu} vCPU, #{machine.ram} GB RAM"
  end

  def registered?(machine_type, os_image) do
    machines()
    |> Enum.any?(fn m -> m.type == machine_type && os_image in m.available_os_images end)
  end

  def registered?(org_id, machine_type, os_image) do
    machines(org_id)
    |> Enum.any?(fn m -> m.type == machine_type && os_image in m.available_os_images end)
  end

  def mac?(machine_type), do: machine_type in mac_machine_types()

  def linux?(machine_type), do: machine_type in linux_machine_types()

  def obsoleted?(_machine_type, os_image), do: os_image not in os_images()

  def default_os_image(machine_type) do
    machines()
    |> Enum.find(&(&1.type == machine_type))
    |> case do
      nil ->
        {:error, "unknown machine type"}

      machine ->
        {:ok, machine.default_os_image}
    end
  end

  def default_os_image(org_id, machine_type) do
    machines(org_id)
    |> Enum.find(&(&1.type == machine_type))
    |> case do
      nil ->
        {:error, "unknown machine type"}

      machine ->
        {:ok, machine.default_os_image}
    end
  end

  def default_linux_os_image do
    linux_machine_types()
    |> List.first()
    |> default_os_image()
  end

  def default_linux_os_image(org_id) do
    linux_machine_types(org_id)
    |> List.first()
    |> default_os_image()
  end

  def default_mac_os_image do
    mac_machine_types()
    |> List.first()
    |> default_os_image()
  end

  def default_mac_os_image(org_id) do
    mac_machine_types(org_id)
    |> List.first()
    |> default_os_image()
  end

  def default_debug_project_machine(org_id), do: linux_machine_types(org_id) |> List.first()
end
