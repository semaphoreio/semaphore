defmodule Rbac.Services.OrganizationDeleted do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "organization_exchange",
    routing_key: "deleted",
    service: "guard.organization_deleted"

  def handle_message(message) do
    Watchman.benchmark("organization_deleted.duration", fn ->
      event = InternalApi.Organization.OrganizationDeleted.decode(message)

      Logger.info("[OrganizationDeleted] Processing: #{event.org_id}")

      GenRetry.retry(
        fn ->
          Logger.info("[OrganizationDeleted] Syncing with rbac pid #{inspect(self())}")
          {:ok, rbi} = Rbac.RoleBindingIdentification.new(org_id: event.org_id)
          Rbac.RoleManagement.retract_roles(rbi)
          Rbac.Store.RbacRole.remove_org_roles(event.org_id)
          Logger.info("[OrganizationDeleted] Finished syncing with rbac pid #{inspect(self())}")
        end,
        retries: 10,
        delay: 1000
      )

      Logger.info("[OrganizationDeleted] Processing finished. #{event.org_id}")
    end)
  end
end
