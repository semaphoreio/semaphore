defmodule Guard.Services.OrganizationSuspended do
  require Logger

  alias Guard.Store.Suspension

  use Tackle.Consumer,
    url: Application.get_env(:guard, :amqp_url),
    exchange: "organization_exchange",
    routing_key: "blocked",
    service: "guard.organization_suspened"

  def handle_message(message) do
    Watchman.benchmark("organization_suspened.duration", fn ->
      event = InternalApi.Organization.OrganizationBlocked.decode(message)

      Logger.info("[OrganizationSuspended] Processing: #{event.org_id}")

      Suspension.add(event.org_id)

      Logger.info("[OrganizationSuspended] Processing finished. #{event.org_id}")
    end)
  end
end
