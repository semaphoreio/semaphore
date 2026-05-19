defmodule PipelinesAPI.Groups.Authorize do
  @moduledoc false
  use Plug.Builder

  def authorize_view_groups(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.people.view", conn)

  def authorize_manage_groups(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.people.manage", conn)
end
