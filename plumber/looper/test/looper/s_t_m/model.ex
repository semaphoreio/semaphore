defmodule Looper.STM.Test.Items do
  use Ecto.Schema

  schema "items" do
    field :state,                   :string
    field :result,                  :string
    field :result_reason,           :string
    field :in_scheduling,           :boolean, read_after_writes: true
    field :description,             :map
    field :recovery_count,          :integer, read_after_writes: true
    field :terminate_request,       :string
    field :terminate_request_desc,  :string
    field :some_id,                 :string
    field :some_other_id,           :string

    timestamps(type: :naive_datetime_usec)
  end

end
