defmodule Front.Models.TestExplorer.DetailedFlakyTest do
  alias __MODULE__
  alias Front.Models.TestExplorer.HistoryItem

  defstruct [
    :id,
    :name,
    :group,
    :runner,
    :file,
    :selected_context,
    disruptions_count: [],
    labels: [],
    contexts: [],
    hashes: [],
    disruption_history: [],
    pass_rates: [],
    p95_durations: [],
    total_counts: [],
    impacts: [],
    available_contexts: [],
    disruption_timestamps: []
  ]

  @type t :: %DetailedFlakyTest{
          id: String.t(),
          name: String.t(),
          group: String.t(),
          runner: String.t(),
          file: String.t(),
          disruptions_count: [non_neg_integer()],
          labels: [String.t()],
          contexts: [String.t()],
          hashes: [String.t()],
          disruption_history: [HistoryItem.t()],
          pass_rates: [float()],
          p95_durations: [float()],
          total_counts: [non_neg_integer()],
          impacts: [non_neg_integer()],
          available_contexts: [String.t()],
          selected_context: String.t(),
          disruption_timestamps: [DateTime.t()]
        }

  def new(params), do: struct(DetailedFlakyTest, params)

  def from_proto(p) do
    dh = Enum.map(p.disruption_history, &HistoryItem.from_proto/1)

    dt =
      Enum.map(p.disruption_timestamps, fn timestamp ->
        DateTime.from_unix!(timestamp.seconds)
      end)

    %DetailedFlakyTest{
      id: p.id,
      name: p.name,
      group: p.group,
      runner: p.runner,
      file: p.file,
      disruptions_count: p.disruptions_count,
      contexts: p.contexts,
      hashes: p.hashes,
      labels: p.labels,
      disruption_history: dh,
      impacts: p.impacts,
      pass_rates: p.pass_rates,
      p95_durations: p.p95_durations,
      total_counts: p.total_counts,
      available_contexts: p.available_contexts,
      selected_context: p.selected_context,
      disruption_timestamps: dt
    }
  end

  def from_json(json) do
    %DetailedFlakyTest{
      id: json["test_id"],
      name: json["test_name"],
      group: json["test_group"],
      runner: json["test_runner"],
      file: json["test_file"],
      disruptions_count: json["test_disruption_count"],
      contexts: json["test_contexts"],
      hashes: json["test_hashes"],
      labels: json["test_labels"],
      disruption_history: json["test_disruption_history"],
      impacts: json["test_impacts"],
      pass_rates: json["test_pass_rates"],
      p95_durations: json["test_p95_durations"],
      total_counts: json["test_total_counts"],
      available_contexts: json["test_available_contexts"],
      selected_context: json["test_selected_context"]
    }
  end
end
