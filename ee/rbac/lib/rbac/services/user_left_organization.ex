defmodule Rbac.Services.UserLeftOrganization do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "user_exchange",
    routing_key: "user_left_organization",
    service: "guard.user_left_organization"

  def handle_message(message) do
    Watchman.benchmark("user_left_organization.duration", fn ->
      event = InternalApi.User.UserLeftOrganization.decode(message)

      Logger.info(
        "[UserLeftOrganization] Processing: org: #{event.org_id}, user: #{event.user_id}"
      )

      if Rbac.RoleManagement.user_part_of_org?(event.user_id, event.org_id) do
        {:ok, rbi} =
          Rbac.RoleBindingIdentification.new(user_id: event.user_id, org_id: event.org_id)

        Rbac.RoleManagement.retract_roles(rbi)
      end

      Logger.info(
        "[UserLeftOrganization] Processing finished. Org: #{event.org_id}, user: #{event.user_id}"
      )
    end)
  end
end
