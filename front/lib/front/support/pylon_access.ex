defmodule Front.Support.PylonAccess do
  @support_tier_features [
    :advanced_support,
    :premium_support,
    :"support-tier-3",
    :"support-tier-4"
  ]

  @spec enabled_for_org?(String.t() | nil) :: boolean()
  def enabled_for_org?(org_id) when is_binary(org_id) and org_id != "" do
    feature_enabled?(:pylon_support_portal, org_id) or
      (feature_enabled?(:pylon_support, org_id) and
         feature_enabled_any?(org_id, @support_tier_features))
  end

  def enabled_for_org?(_), do: false

  @spec visible_for_org?(String.t() | nil, boolean()) :: boolean()
  def visible_for_org?(org_id, has_contact_support_permission?)
      when is_boolean(has_contact_support_permission?) do
    enabled_for_org?(org_id) and
      (not feature_enabled?(:restricted_support, org_id) or has_contact_support_permission?)
  end

  defp feature_enabled_any?(org_id, features) do
    features
    |> Enum.any?(&feature_enabled?(&1, org_id))
  end

  defp feature_enabled?(feature, org_id) do
    FeatureProvider.feature_enabled?(feature, param: org_id)
  rescue
    _ -> false
  end
end
