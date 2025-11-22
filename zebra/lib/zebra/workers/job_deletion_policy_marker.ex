defmodule Zebra.Workers.JobDeletionPolicyMarker do
  require Logger

  alias Zebra.Models.Job
  alias Google.Protobuf.Timestamp

  use Tackle.Consumer,
    url: Application.get_env(:zebra, :amqp_url),
    service: "zebra",
    exchange: "policy_exchange",
    routing_key: "policy_applied",
    retry_limit: 10,
    retry_delay: 10

  def handle_message(message) do
    decoded = InternalApi.Usage.OrganizationPolicyApply.decode(message)
    org_id = decoded.org_id
    cutoff_date = cutoff_date_from_proto(decoded.cutoff_date)
    days = policy_days()

    {count, _} = Job.mark_jobs_for_deletion(org_id, cutoff_date, days)
    Logger.info("Marked #{count} jobs for deletion for org #{org_id}.")
  end

  defp policy_days do
    Application.fetch_env!(:zebra, __MODULE__)
    |> Keyword.fetch!(:days)
  end

  defp cutoff_date_from_proto(timestamp = %Timestamp{}) do
    total_nanoseconds = timestamp.seconds * 1_000_000_000 + timestamp.nanos

    total_nanoseconds
    |> DateTime.from_unix!(:nanosecond)
    |> DateTime.truncate(:second)
  end

  defp cutoff_date_from_proto(nil) do
    raise ArgumentError, "cutoff_date is missing in policy payload"
  end
end
