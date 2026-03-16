defmodule Front.Models.Billing.AddonGroup do
  alias __MODULE__

  defstruct name: "",
            display_name: "",
            description: "",
            type: :unspecified,
            addons: []

  @type group_type :: :unspecified | :exclusive | :regular

  @type t :: %AddonGroup{
          name: String.t(),
          display_name: String.t(),
          description: String.t(),
          type: group_type(),
          addons: [AddonGroup.Addon.t()]
        }

  def from_grpc(group) do
    %AddonGroup{
      name: group.name,
      display_name: group.display_name,
      description: group.description,
      type: type_from_grpc(group.type),
      addons: Enum.map(group.addons, &AddonGroup.Addon.from_grpc/1)
    }
  end

  def to_json(group = %AddonGroup{}) do
    %{
      name: group.name,
      display_name: group.display_name,
      description: group.description,
      type: Atom.to_string(group.type),
      addons: Enum.map(group.addons, &AddonGroup.Addon.to_json/1)
    }
  end

  defp type_from_grpc(:ADDON_GROUP_TYPE_EXCLUSIVE), do: :exclusive
  defp type_from_grpc(:ADDON_GROUP_TYPE_REGULAR), do: :regular
  defp type_from_grpc(1), do: :exclusive
  defp type_from_grpc(2), do: :regular
  defp type_from_grpc(_), do: :unspecified
end

defmodule Front.Models.Billing.AddonGroup.Addon do
  alias __MODULE__

  defstruct name: "",
            display_name: "",
            description: "",
            price: "",
            enabled: false,
            modifiable: true,
            last_modified_at: nil

  @type t :: %Addon{
          name: String.t(),
          display_name: String.t(),
          description: String.t(),
          price: String.t(),
          enabled: boolean(),
          modifiable: boolean(),
          last_modified_at: DateTime.t() | nil
        }

  def from_grpc(addon) do
    %Addon{
      name: addon.name,
      display_name: addon.display_name,
      description: addon.description,
      price: addon.price,
      enabled: addon.enabled,
      modifiable: addon.modifiable,
      last_modified_at: parse_timestamp(addon.last_modified_at)
    }
  end

  def to_json(addon = %Addon{}) do
    %{
      name: addon.name,
      display_name: addon.display_name,
      description: addon.description,
      price: addon.price,
      enabled: addon.enabled,
      modifiable: addon.modifiable
    }
  end

  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(%{seconds: 0}), do: nil
  defp parse_timestamp(%{seconds: seconds}), do: DateTime.from_unix!(seconds)
end
