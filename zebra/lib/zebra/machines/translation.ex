defmodule Zebra.Machines.Translation do
  @moduledoc """
  Maps the machine a job requested to the machine requested from the agent provider.

  Some machine families are mapped to a newer family when the organization has the
  corresponding feature flag enabled. Only the machine type changes; the OS image is kept.

  `translate/3` only reads feature flags. It records no metrics, so it is safe to call
  from read paths. Callers that want to record a translation do so themselves.
  """

  @type result :: {machine_type :: String.t(), os_image :: String.t(), translated? :: boolean()}

  @doc """
  Returns `{machine_type, os_image, translated?}` for a job's machine and organization.

  `translated?` is true when the organization has the migration flag for the machine's
  family enabled, even if the type itself has no mapping.
  """
  @spec translate(String.t() | nil, String.t() | nil, String.t() | nil) :: result()
  def translate(machine_type, os_image, org_id) do
    machine_type = machine_type || ""
    os_image = os_image || ""

    if migration_enabled?(machine_type, org_id) do
      {new_type, new_os_image} = map_machine(machine_type, os_image)
      {new_type, new_os_image, true}
    else
      {machine_type, os_image, false}
    end
  end

  @doc """
  True when the machine type belongs to a family that may be translated.
  Only these types need a feature flag lookup.
  """
  @spec translatable?(String.t() | nil) :: boolean()
  def translatable?(machine_type), do: e1_family?(machine_type) or e2_family?(machine_type)

  @doc """
  The mapping itself, without any flag check.
  """
  @spec map_machine(String.t(), String.t()) :: {String.t(), String.t()}
  def map_machine("e1-standard-2", os_image), do: {"f1-standard-2", os_image}
  def map_machine("e1-standard-4", os_image), do: {"f1-standard-2", os_image}
  def map_machine("e1-standard-8", os_image), do: {"f1-standard-4", os_image}
  def map_machine("e2-standard-2", os_image), do: {"f1-standard-2", os_image}
  def map_machine("e2-standard-4", os_image), do: {"f1-standard-4", os_image}
  def map_machine(machine_type, os_image), do: {machine_type, os_image}

  defp migration_enabled?(machine_type, org_id) do
    cond do
      e1_family?(machine_type) -> flag_enabled?("e1_to_f1_migration", org_id)
      e2_family?(machine_type) -> flag_enabled?("e2_to_f1_migration", org_id)
      true -> false
    end
  end

  defp flag_enabled?(_flag, nil), do: false
  defp flag_enabled?(flag, org_id), do: FeatureProvider.feature_enabled?(flag, param: org_id)

  defp e1_family?(machine_type) when is_binary(machine_type),
    do: String.starts_with?(machine_type, "e1-")

  defp e1_family?(_), do: false

  defp e2_family?(machine_type) when is_binary(machine_type),
    do: String.starts_with?(machine_type, "e2-")

  defp e2_family?(_), do: false
end
