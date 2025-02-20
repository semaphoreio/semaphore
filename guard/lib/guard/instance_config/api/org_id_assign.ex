defmodule Guard.InstanceConfig.Api.OrgIdAssign do
  use Plug.Builder
  import Guard.InstanceConfig.Api.Utils
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    with org_id <- conn.query_params["org_id"],
         {:org_id_nil, false} <- {:org_id_nil, is_nil(org_id) || org_id == ""},
         org <- Guard.Api.Organization.fetch(org_id),
         {:org_not_found, false} <- {:org_not_found, is_nil(org)},
         org_username <- org.org_username do
      merge_assigns(conn, org_username: org_username, org_id: org_id)
    else
      {:org_id_nil, true} ->
        Logger.error("org_id is nil")

        conn
        |> put_notification(:alert, "Organization ID is required")
        |> redirect_to_front("")
        |> halt()

      {:org_not_found, true} ->
        Logger.error("Organization not found")

        conn
        |> put_notification(:alert, "Organization not found")
        |> redirect_to_front("")
        |> halt()
    end
  end
end
