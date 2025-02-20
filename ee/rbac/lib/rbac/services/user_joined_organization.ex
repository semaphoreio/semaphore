defmodule Rbac.Services.UserJoinedOrganization do
  require Logger
  alias Rbac.TempSync
  alias Rbac.RoleManagement

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "user_exchange",
    routing_key: "user_joined_organization",
    service: "guard.user_joined_organization"

  def handle_message(message) do
    Watchman.benchmark("user_joined_organization.duration", fn ->
      event = InternalApi.User.UserJoinedOrganization.decode(message)

      Logger.info(
        "[UserJoinedOrganization] Processing: org: #{event.org_id}, user: #{event.user_id}"
      )

      Rbac.Refresh.Organization.refresh([event.org_id])

      if !RoleManagement.user_part_of_org?(event.user_id, event.org_id) do
        Logger.info("[UserJoinedOrganization] Syncing with RBAC")
        TempSync.assign_org_member_role(event.user_id, event.org_id)
      end

      Logger.info(
        "[UserJoinedOrganization] Processing finished. Org: #{event.org_id}, user: #{event.user_id}"
      )
    end)
  end
end
