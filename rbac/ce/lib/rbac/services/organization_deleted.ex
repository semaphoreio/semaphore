defmodule Rbac.Services.OrganizationDeleted do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "organization_exchange",
    routing_key: "deleted",
    service: "rbac.organization_deleted"

  def handle_message(message) do
    Watchman.benchmark("organization_deleted.duration", fn ->
      event = InternalApi.Organization.OrganizationDeleted.decode(message)

      Logger.info("[OrganizationDeleted] Processing: #{event.org_id}")

      Rbac.Models.RoleAssignment.delete_all_by_org_id(event.org_id)

      Logger.info("[OrganizationDeleted] Processing finished. #{event.org_id}")
    end)
  end
end
