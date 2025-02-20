defmodule Ppl.OrgEventsConsumer do
  @moduledoc """
  Receives Organization suspend events from the RabbitMQ and terminates all active
  pipelines from that organization
  """

  alias InternalApi.Organization.OrganizationBlocked
  alias Ppl.Ppls.Model.PplsQueries
  alias Util.Metrics
  alias LogTee, as: LT

  use Tackle.Consumer,
    url: System.get_env("RABBITMQ_URL"),
    exchange: "organization_exchange",
    routing_key: "blocked",
    service: "plumber"


  def handle_message(message)do
    Metrics.benchmark("OrgEvenstConsumer.org_blocked_event", fn ->
      message
      |> decode_message()
      |> terminate_pipelines()
    end)
  end

  defp decode_message(message) do
    Wormhole.capture(OrganizationBlocked, :decode, [message], stacktrace: true)
  end

  defp terminate_pipelines({:ok, %{org_id: org_id}})
    when is_binary(org_id) and org_id != "" do
      %{
        org_id: org_id,
        terminate_request: "stop",
        terminate_request_desc: "organization blocked",
        terminated_by: "admin"
      }
      |> PplsQueries.terminate_all()
      |> LT.info("Terminating pipelines from organization #{org_id}")
  end
  defp terminate_pipelines(error),
    do: error |> LT.warn("Error while processing org blocked RabbitMQ message:")
end
