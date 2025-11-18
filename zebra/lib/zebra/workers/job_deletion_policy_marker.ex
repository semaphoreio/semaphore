defmodule Zebra.Workers.JobDeletionPolicyMarker do
  require Logger

  alias Zebra.Models.Job

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
    cutoff_date = decoded.cutoff_date

    days =
      Application.fetch_env!(:zebra, Zebra.Workers.JobDeletionPolicyWorker)
      |> Keyword.fetch!(:days)

    {count, _} = Job.mark_jobs_for_deletion(org_id, cutoff_date, days)
    Logger.info("Marked #{count} jobs for deletion for org #{org_id}.")
  end
end
