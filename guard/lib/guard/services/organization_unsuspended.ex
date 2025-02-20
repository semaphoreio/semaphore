defmodule Guard.Services.OrganizationUnsuspended do
  require Logger

  alias Guard.Store.Suspension

  use Tackle.Consumer,
    url: Application.get_env(:guard, :amqp_url),
    exchange: "organization_exchange",
    routing_key: "unblocked",
    service: "guard.organization_unsuspened"

  def handle_message(message) do
    Watchman.benchmark("organization_unsuspened.duration", fn ->
      event = InternalApi.Organization.OrganizationUnblocked.decode(message)

      Logger.info("[OrganizationUnsuspended] Processing: #{event.org_id}")

      Suspension.remove(event.org_id)

      Logger.info("[OrganizationUnsuspended] Processing finished. #{event.org_id}")
    end)
  end
end
