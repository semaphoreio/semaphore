defmodule Front.FeatureProviderInvalidatorWorker do
  use Broadway

  require Logger

  @routing_keys ~w(
    machines_changed
    organization_machines_changed
    features_changed
    organization_features_changed
  )

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayRabbitMQ.Producer,
           queue: "",
           connection: amqp_url(),
           after_connect: fn channel ->
             AMQP.Exchange.declare(channel, "feature_exchange", :direct, durable: true)
           end,
           declare: [
             durable: false,
             auto_delete: true,
             exclusive: true
           ],
           bindings:
             Enum.map(@routing_keys, fn rk ->
               {"feature_exchange", routing_key: rk}
             end),
           on_failure: :reject,
           metadata: [:routing_key]},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: 1,
          max_demand: 1
        ]
      ]
    )
  end

  @impl true
  def handle_message(_processor, message, _context) do
    case message.metadata.routing_key do
      "machines_changed" ->
        handle_machines_changed(message.data)

      "organization_machines_changed" ->
        handle_organization_machines_changed(message.data)

      "features_changed" ->
        handle_features_changed(message.data)

      "organization_features_changed" ->
        handle_organization_features_changed(message.data)

      unknown ->
        Logger.warning("[FEATURE PROVIDER INVALIDATOR WORKER] unknown routing key: #{unknown}")
    end

    message
  end

  defp handle_machines_changed(_payload) do
    log("invalidating machines")
    {:ok, _} = FeatureProvider.list_machines(reload: true)
  end

  defp handle_organization_machines_changed(payload) do
    event = InternalApi.Feature.OrganizationMachinesChanged.decode(payload)
    log("invalidating machines for org #{event.org_id}")
    {:ok, _} = FeatureProvider.list_machines(reload: true, param: event.org_id)
  end

  defp handle_features_changed(_payload) do
    log("invalidating features")
    {:ok, _} = FeatureProvider.list_features(reload: true)
  end

  defp handle_organization_features_changed(payload) do
    event = InternalApi.Feature.OrganizationFeaturesChanged.decode(payload)
    log("invalidating features for org #{event.org_id}")
    {:ok, _} = FeatureProvider.list_features(reload: true, param: event.org_id)
  end

  defp log(message) do
    Logger.info("[FEATURE PROVIDER INVALIDATOR WORKER] #{message}")
  end

  defp amqp_url do
    Application.get_env(:front, :amqp_url)
  end
end
