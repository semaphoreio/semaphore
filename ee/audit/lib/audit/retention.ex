defmodule Audit.Retention do
  @moduledoc """
  Audit log retention is enabled per organization by the `audit_logs_retention`
  feature. The policy marker checks it before marking events and the deleter
  checks it again before deleting them. A failed lookup counts as disabled.
  """

  @feature :audit_logs_retention

  @spec enabled?(String.t()) :: boolean()
  def enabled?(org_id), do: FeatureProvider.feature_enabled?(@feature, param: org_id)
end
