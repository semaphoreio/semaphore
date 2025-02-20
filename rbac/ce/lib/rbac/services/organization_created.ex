defmodule Rbac.Services.OrganizationCreated do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "organization_exchange",
    routing_key: "created",
    service: "rbac.organization_created"

  def handle_message(message) do
    Watchman.benchmark("organization_created.duration", fn ->
      event = InternalApi.Organization.OrganizationCreated.decode(message)

      Logger.info("[OrganizationCreated] Processing: #{event.org_id}")

      retry_assign_owner_role(event.org_id, 0)

      Logger.info("[OrganizationCreated] Processing finished. #{event.org_id}")
    end)
  end

  @max_retries 3

  defp retry_assign_owner_role(_org_id, @max_retries) do
    Logger.error("[OrganizationCreated] Failed to assign owner role")
  end

  defp retry_assign_owner_role(org_id, retry_count) do
    case Rbac.Api.Organization.get(org_id) do
      {:ok, org} ->
        Rbac.Models.RoleAssignment.assign_owner_role(org.owner_id, org.org_id)

        Logger.info(
          "[OrganizationCreated] Assigning owner role for user #{org.owner_id} in org: #{org.org_id}"
        )

      {:error, _} ->
        Logger.info("[OrganizationCreated] Retrying to assign owner role for org: #{org_id}")
        :timer.sleep(3_000)
        retry_assign_owner_role(org_id, retry_count + 1)
    end
  end
end
