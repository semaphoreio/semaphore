defmodule Looper.StateResidency.Test.EntityTrace do
  use Ecto.Schema

  schema "entity_traces" do
    field :entity_id, Ecto.UUID
    field :created_at, :utc_datetime_usec
    field :pending_at, :utc_datetime_usec
    field :queuing_at, :utc_datetime_usec
    field :running_at, :utc_datetime_usec
    field :stopping_at, :utc_datetime_usec
    field :done_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

end
