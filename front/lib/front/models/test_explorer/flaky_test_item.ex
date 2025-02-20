defmodule Front.Models.TestExplorer.FlakyTestItem do
  alias Front.Models.TestExplorer.HistoryItem
  alias __MODULE__

  defstruct [
    :test_id,
    :test_name,
    :test_group,
    :test_runner,
    :test_suite,
    :test_file,
    :disruptions_count,
    :pass_rate,
    :labels,
    :latest_disruption_timestamp,
    :latest_disruption_hash,
    :latest_disruption_run_id,
    :latest_disruption_job_url,
    :scheduled,
    :resolved,
    :disruption_history,
    :ticket_url,
    :first_disruption_at,
    :age
  ]

  @type t :: %FlakyTestItem{
          test_id: String.t(),
          test_name: String.t(),
          test_group: String.t(),
          test_runner: String.t(),
          test_suite: String.t(),
          test_file: String.t(),
          disruptions_count: non_neg_integer(),
          pass_rate: non_neg_integer(),
          labels: [String.t()],
          latest_disruption_timestamp: DateTime.t(),
          latest_disruption_hash: String.t(),
          latest_disruption_run_id: String.t(),
          latest_disruption_job_url: String.t(),
          scheduled: boolean(),
          resolved: boolean(),
          disruption_history: [HistoryItem.t()],
          ticket_url: String.t(),
          first_disruption_at: DateTime.t(),
          age: non_neg_integer()
        }

  def new(params), do: struct(FlakyTestItem, params)

  def from_proto(p) do
    last_disruption_at = DateTime.from_unix!(p.latest_disruption_at.seconds)
    first_disruption_at = DateTime.from_unix!(p.first_disruption_at.seconds)

    dh = Enum.map(p.disruption_history, &HistoryItem.from_proto/1)

    %FlakyTestItem{
      test_id: p.test_id,
      test_name: p.test_name,
      test_group: p.test_group,
      test_runner: p.test_runner,
      test_suite: p.test_suite,
      test_file: p.test_file,
      disruptions_count: p.disruptions_count,
      pass_rate: p.pass_rate,
      labels: p.labels,
      latest_disruption_timestamp: last_disruption_at,
      latest_disruption_hash: p.latest_disruption_hash,
      latest_disruption_run_id: p.latest_disruption_run_id,
      latest_disruption_job_url: "/jobs/#{p.latest_disruption_run_id}",
      resolved: p.resolved,
      scheduled: p.scheduled,
      disruption_history: dh,
      ticket_url: p.ticket_url,
      first_disruption_at: first_disruption_at,
      age: p.age
    }
  end

  def from_json(json) do
    %FlakyTestItem{
      test_id: json["test_id"],
      test_name: json["test_name"],
      test_group: json["test_group"],
      test_runner: json["test_runner"],
      test_suite: json["test_suite"],
      test_file: json["test_file"],
      disruptions_count: json["disruptions_count"],
      pass_rate: json["pass_rate"],
      labels: json["test_labels"],
      latest_disruption_timestamp: json["latest_disruption_timestamp"],
      latest_disruption_hash: json["latest_disruption_hash"],
      latest_disruption_run_id: json["latest_disruption_run_id"],
      latest_disruption_job_url: "/jobs/#{json["latest_disruption_run_id"]}",
      scheduled: json["scheduled"],
      resolved: json["resolved"],
      disruption_history: json["disruption_history"],
      ticket_url: json["ticket_url"],
      first_disruption_at: json["first_disruption_at"],
      age: json["age"]
    }
  end
end
