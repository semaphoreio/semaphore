defmodule FrontWeb.Plug.AssignBillingInfo do
  import Plug.Conn

  def init(options), do: options

  def call(conn, opts) do
    org_id = conn.assigns.organization_id

    # Only assign billing info if the feature is enabled for the organization
    # and there is an organization id
    # The organization id is not available in the me.DOMAIN endpoints
    if org_id && FeatureProvider.feature_enabled?(:billing, org_id) do
      do_call(conn, opts)
    else
      conn
    end
  end

  defp do_call(conn, _opts) do
    organization_id = conn.assigns.organization_id

    cache_opts =
      if conn.params["force_cold_boot"] do
        [reload_cache?: true]
      else
        []
      end

    try do
      current_spending = Front.Models.Billing.current_spending(organization_id, cache_opts)

      assign(conn, :current_spending, current_spending)
    rescue
      _ ->
        assign(conn, :current_spending, :none)
    end
  end
end
