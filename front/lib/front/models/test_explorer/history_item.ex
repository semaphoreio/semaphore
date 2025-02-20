defmodule Front.Models.TestExplorer.HistoryItem do
  alias __MODULE__

  defstruct [
    :day,
    :count
  ]

  @type t :: %HistoryItem{
          day: DateTime.t(),
          count: non_neg_integer()
        }

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(HistoryItem, params)

  def from_proto(p) do
    %HistoryItem{
      day: DateTime.from_unix!(p.day.seconds),
      count: p.count
    }
  end

  def from_json(json) do
    %HistoryItem{
      day: json["day"],
      count: json["count"]
    }
  end
end
