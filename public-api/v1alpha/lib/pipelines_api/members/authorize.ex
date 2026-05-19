defmodule PipelinesAPI.Members.Authorize do
  @moduledoc false
  use Plug.Builder

  def authorize_view_people(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.people.view", conn)

  def authorize_manage_people(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.people.manage", conn)
end
