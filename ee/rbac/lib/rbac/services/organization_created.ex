defmodule Rbac.Services.OrganizationCreated do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "organization_exchange",
    routing_key: "created",
    service: "guard.organization_created"

  def handle_message(message) do
    Watchman.benchmark("organization_created.duration", fn ->
      event = InternalApi.Organization.OrganizationCreated.decode(message)

      Logger.info("[OrganizationCreated] Processing: #{event.org_id}")

      GenRetry.retry(
        fn ->
          Logger.info("[OrganizationCreated] Creating roles for new org")

          Rbac.Store.RbacRole.create_default_roles_for_organization(event.org_id)
          Rbac.TempSync.assign_org_owner_role(event.org_id)
          owner_id = Rbac.TempSync.get_org_creator_id(event.org_id)
          Rbac.Events.Authorization.publish("role_assigned", owner_id, event.org_id)
        end,
        retries: 10,
        delay: 1000
      )

      Logger.info("[OrganizationCreated] Processing finished. #{event.org_id}")
    end)
  end
end
