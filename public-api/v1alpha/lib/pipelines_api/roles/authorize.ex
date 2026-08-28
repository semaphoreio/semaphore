defmodule PipelinesAPI.Roles.Authorize do
  @moduledoc false
  use Plug.Builder

  def authorize_view_roles(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.custom_roles.view", conn)

  def authorize_manage_roles(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.custom_roles.manage", conn)
end
