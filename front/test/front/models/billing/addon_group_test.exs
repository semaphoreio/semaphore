defmodule Front.Models.Billing.AddonGroupTest do
  use ExUnit.Case

  alias Front.Models.Billing.AddonGroup
  alias Front.Models.Billing.AddonGroup.Addon

  describe "AddonGroup.from_grpc/1" do
    test "converts a grpc addon group to a model" do
      grpc_group = %{
        name: "support",
        display_name: "Support",
        description: "Support tiers",
        type: :ADDON_GROUP_TYPE_EXCLUSIVE,
        disabling_is_final: true,
        on_cooldown: true,
        addons: [
          %{
            name: "support-tier-1",
            display_name: "Community",
            description: "Community support",
            price: "$ 0.00",
            enabled: true,
            modifiable: true,
            self_service: false,
            last_modified_at: nil
          }
        ]
      }

      result = AddonGroup.from_grpc(grpc_group)

      assert result.name == "support"
      assert result.display_name == "Support"
      assert result.description == "Support tiers"
      assert result.type == :exclusive
      assert result.disabling_is_final == true
      assert result.on_cooldown == true
      assert length(result.addons) == 1

      addon = hd(result.addons)
      assert addon.name == "support-tier-1"
      assert addon.display_name == "Community"
      assert addon.price == "$ 0.00"
      assert addon.enabled == true
      assert addon.modifiable == true
      assert addon.self_service == false
    end

    test "maps regular group type" do
      grpc_group = %{
        name: "extras",
        display_name: "Extras",
        description: "",
        type: :ADDON_GROUP_TYPE_REGULAR,
        addons: [],
        disabling_is_final: false,
        on_cooldown: false
      }

      result = AddonGroup.from_grpc(grpc_group)
      assert result.type == :regular
    end

    test "maps unspecified group type" do
      grpc_group = %{
        name: "other",
        display_name: "Other",
        description: "",
        type: :ADDON_GROUP_TYPE_UNSPECIFIED,
        addons: [],
        disabling_is_final: false,
        on_cooldown: false
      }

      result = AddonGroup.from_grpc(grpc_group)
      assert result.type == :unspecified
    end
  end

  describe "AddonGroup.to_json/1" do
    test "serializes addon group to json map" do
      group = %AddonGroup{
        name: "support",
        display_name: "Support",
        description: "Support tiers",
        type: :exclusive,
        disabling_is_final: true,
        on_cooldown: true,
        addons: [
          %Addon{
            name: "tier-1",
            display_name: "Basic",
            description: "Basic support",
            price: "$ 10.00",
            enabled: true,
            modifiable: true,
            self_service: false
          }
        ]
      }

      json = AddonGroup.to_json(group)

      assert json.name == "support"
      assert json.display_name == "Support"
      assert json.description == "Support tiers"
      assert json.type == "exclusive"
      assert json.disabling_is_final == true
      assert json.on_cooldown == true
      assert length(json.addons) == 1

      addon_json = hd(json.addons)
      assert addon_json.name == "tier-1"
      assert addon_json.display_name == "Basic"
      assert addon_json.price == "$ 10.00"
      assert addon_json.enabled == true
      assert addon_json.modifiable == true
      assert addon_json.self_service == false
    end
  end

  describe "Addon.from_grpc/1" do
    test "parses timestamp" do
      grpc_addon = %{
        name: "tier-1",
        display_name: "Basic",
        description: "desc",
        price: "$ 0.00",
        enabled: false,
        modifiable: true,
        self_service: true,
        last_modified_at: %{seconds: 1_700_000_000}
      }

      addon = Addon.from_grpc(grpc_addon)
      assert addon.last_modified_at != nil
    end

    test "handles nil timestamp" do
      grpc_addon = %{
        name: "tier-1",
        display_name: "Basic",
        description: "desc",
        price: "$ 0.00",
        enabled: false,
        modifiable: true,
        self_service: true,
        last_modified_at: nil
      }

      addon = Addon.from_grpc(grpc_addon)
      assert addon.last_modified_at == nil
    end

    test "handles zero timestamp" do
      grpc_addon = %{
        name: "tier-1",
        display_name: "Basic",
        description: "desc",
        price: "$ 0.00",
        enabled: false,
        modifiable: true,
        self_service: true,
        last_modified_at: %{seconds: 0}
      }

      addon = Addon.from_grpc(grpc_addon)
      assert addon.last_modified_at == nil
    end
  end
end
