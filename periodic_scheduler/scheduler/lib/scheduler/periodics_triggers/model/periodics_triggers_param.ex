defmodule Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersParam do
  @moduledoc """
  Periodic parameter value schema
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :name, :string
    field :value, :string
  end

  def changeset(param, params \\ %{}) do
    param
    |> Ecto.Changeset.cast(params, ~w(name value)a, empty_values: [])
    |> Ecto.Changeset.validate_required(~w(name)a)
  end
end
