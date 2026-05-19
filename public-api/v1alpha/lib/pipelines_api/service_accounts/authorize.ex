defmodule PipelinesAPI.ServiceAccounts.Authorize do
  @moduledoc false
  use Plug.Builder

  def authorize_manage(conn, _opts),
    do:
      PipelinesAPI.SharedAuthorize.check_permission("organization.service_accounts.manage", conn)

  def authorize_view(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.service_accounts.view", conn)
end
