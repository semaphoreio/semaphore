defmodule Looper.StateResidency.Test.Entity do
  use Ecto.Schema

  schema "entities" do
    field :state,     :string
    field :entity_id, Ecto.UUID

    timestamps(type: :utc_datetime_usec)
  end

end
