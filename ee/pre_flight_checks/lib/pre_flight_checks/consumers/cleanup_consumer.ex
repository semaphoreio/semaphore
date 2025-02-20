defmodule PreFlightChecks.Consumers.CleanupConsumer do
  @moduledoc """
  RabbitMQ consumer listening on `` exchange

  Responsible for clean-up of pre-flight checks
  for removed organizations and projects
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:pre_flight_checks, :amqp_url),
    service: "pre_flight_checks_hub",
    routes: [
      {"organization_exchange", "deleted", :handle_organization_messages},
      {"project_exchange", "deleted", :handle_project_messages}
    ]

  alias PreFlightChecks.DestroyTraces.DestroyTraceQueries, as: TraceQueries
  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFCQueries
  alias PreFlightChecks.ProjectPFC.Model.ProjectPFCQueries

  alias InternalApi.Organization.OrganizationDeleted
  alias InternalApi.Projecthub.ProjectDeleted

  require Logger

  @doc """
  Handler for organization_exchange messages under `deleted` routing key

  Cleans up pre-flight checks for deleted organizations
  """
  @spec handle_organization_messages(String.t()) :: :ok
  def handle_organization_messages(message),
    do: handle_message(message, &OrganizationDeleted.decode/1)

  @doc """
  Handler for project_exchange messages under `deleted` routing key

  Cleans up pre-flight checks for deleted projects
  """
  @spec handle_project_messages(String.t()) :: :ok
  def handle_project_messages(message),
    do: handle_message(message, &ProjectDeleted.decode/1)

  defp handle_message(message, decoder) do
    case decode_and_register_event(message, decoder) do
      {:ok, {event, trace}} ->
        log_event(event)
        handle_event(event, trace)
        :ok

      {:error, reason} ->
        log_error(message, reason)
    end
  end

  defp decode_and_register_event(message, decoder) do
    Wormhole.capture(
      fn ->
        decoded_event = decoder.(message)
        {:ok, trace} = TraceQueries.register(decoded_event)
        {decoded_event, trace}
      end,
      stacktrace: true
    )
  end

  defp handle_event(%OrganizationDeleted{org_id: organization_id}, trace) do
    case OrganizationPFCQueries.remove(organization_id) do
      {:ok, ^organization_id} -> TraceQueries.resolve_success(trace)
      {:error, _reason} -> TraceQueries.resolve_failure(trace)
    end
  end

  defp handle_event(%ProjectDeleted{project_id: project_id}, trace) do
    case ProjectPFCQueries.remove(project_id) do
      {:ok, ^project_id} -> TraceQueries.resolve_success(trace)
      {:error, _reason} -> TraceQueries.resolve_failure(trace)
    end
  end

  defp log_event(%OrganizationDeleted{org_id: org_id, timestamp: %{seconds: seconds}}) do
    Logger.info("Received event OrganizationDeleted [org_id: #{org_id}, timestamp: #{seconds}]")
  end

  defp log_event(%ProjectDeleted{project_id: prj_id, timestamp: %{seconds: seconds}}) do
    Logger.info("Received event ProjectDeleted [project_id: #{prj_id}, timestamp: #{seconds}]")
  end

  defp log_error(message, reason) do
    Logger.error("message=[#{message}] reason=#{inspect(reason)} Unable to process message")
  end
end
