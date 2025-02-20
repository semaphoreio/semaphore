defmodule Scheduler.Periodics.Model.PeriodicsParam do
  @moduledoc """
  Periodic parameter schema
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :name, :string
    field :description, :string
    field :required, :boolean
    field :options, {:array, :string}, default: []
    field :default_value, :string
  end

  @all_fields ~w(name description required options default_value)a
  @required_fields ~w(name required)a

  def changeset(param, params \\ %{}) do
    param
    |> Ecto.Changeset.cast(params, @all_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
  end
end
