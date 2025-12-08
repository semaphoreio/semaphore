defmodule Zebra.JobDeletedPublisher do
  @callback publish(String.t(), DateTime.t()) :: :ok | {:error, term()}

  require Logger

  alias Google.Protobuf.Timestamp

  @spec publish(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def publish(org_id, job_id, project_id) do
    case Application.get_env(:zebra, :job_deleted_publisher, __MODULE__) do
      __MODULE__ ->
        do_publish(org_id, job_id, project_id)

      module ->
        module.publish(org_id, job_id, project_id)
    end
  end

  defp do_publish(org_id, job_id, project_id) do
    message =
      %{
        org_id: org_id,
        job_id: job_id,
        project_id: project_id,
        deleted_at: DateTime.utc_now() |> to_timestamp()
      }
      |> Poison.encode!()

    Logger.info("Publishing job deleted event for job #{job_id} (org: #{org_id}, project: #{project_id})")

    %{channel: channel_name, exchange: exchange, routing_key: routing_key} = publish_options()

    {:ok, channel} = AMQP.Application.get_channel(channel_name)

    Tackle.Exchange.create(channel, exchange)
    :ok = Tackle.Exchange.publish(channel, exchange, message, routing_key)
  end

  defp publish_options do
    config = Application.get_env(:zebra, Zebra.JobDeletedPublisher, [])

    %{
      channel: Keyword.get(config, :channel, :job_deleted),
      exchange: Keyword.get(config, :exchange, "zebra_internal_api"),
      routing_key: Keyword.get(config, :routing_key, "zebra.job_deleted")
    }
  end

  defp to_timestamp(datetime) do
    Timestamp.new(seconds: DateTime.to_unix(datetime))
  end
end
