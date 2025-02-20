defmodule Guard.Services.OrganizationMachinesChanged do
  @doc """
  This module consumes RabbitMQ machine state change events
  and updates plan default machine type and OS image for organization.
  """

  use Tackle.Consumer,
    url: Application.get_env(:guard, :amqp_url),
    exchange: "feature_exchange",
    routing_key: "organization_machines_changed",
    service: "guard",
    queue: :dynamic,
    queue_opts: [
      durable: false,
      auto_delete: true,
      exclusive: true
    ]

  require Logger

  def handle_message(message) do
    event = InternalApi.Feature.OrganizationFeaturesChanged.decode(message)
    organization = Guard.FrontRepo.get(Guard.FrontRepo.Organization, event.org_id)

    case organization do
      nil -> Logger.warn("Machines changed for non-existent organization: #{event.org_id}")
      _ -> update_plan_defaults(organization)
    end
  end

  def update_plan_defaults(organization) do
    case Guard.FeatureHubProvider.provide_default_machine(organization.id, []) do
      {:ok, default_machine} ->
        update_organization_settings(organization, %{
          "plan_machine_type" => default_machine.type,
          "plan_os_image" => default_machine.default_os_image
        })

      {:error, _} ->
        Logger.warn("Missing default machine for organization: #{organization.id}")
    end
  end

  def update_organization_settings(organization, settings) do
    new_settings = Map.merge(organization.settings || %{}, settings)

    organization
    |> Ecto.Changeset.cast(%{settings: new_settings}, [:settings])
    |> Guard.FrontRepo.update()
    |> case do
      {:ok, _organization} ->
        Logger.debug("Updated plan defaults for organization: #{organization.id}")

      {:error, reason} ->
        Logger.error("Unable to update plan defaults - #{inspect(reason)}")
    end
  end
end
