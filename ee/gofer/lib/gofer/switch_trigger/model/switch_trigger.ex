defmodule Gofer.SwitchTrigger.Model.SwitchTrigger do
  @moduledoc """
  Represents one trigger of one switch.
  Holds data about who and when triggered switch and which switch's targets
  should be triggered.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Gofer.Switch.Model.Switch

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts type: :naive_datetime_usec
  schema "switch_triggers" do
    belongs_to(:switches, Switch, type: Ecto.UUID, foreign_key: :switch_id)
    field(:auto_triggered, :boolean, default: false)
    field(:triggered_by, :string)
    field(:triggered_at, :utc_datetime_usec)
    field(:override, :boolean, default: false)
    field(:target_names, {:array, :string})
    field(:env_vars_for_target, :map)
    field(:request_token, :string)
    field(:processed, :boolean, default: false)

    timestamps()
  end

  @required_fields ~w(id switch_id triggered_by triggered_at target_names request_token)a
  @optional_fields ~w(override processed auto_triggered env_vars_for_target)a

  @doc """
  Examples:

     iex> alias Gofer.SwitchTrigger.Model.SwitchTrigger
     iex> SwitchTrigger.changeset(%SwitchTrigger{}) |> Map.get(:valid?)
     false

     iex> alias Gofer.SwitchTrigger.Model.SwitchTrigger
     iex> params = %{"switch_id" => UUID.uuid4(), "target_names" => ["stg", "prod"],
     ...>            "request_token" => "123", "triggered_at" => DateTime.utc_now(),
     ...>            "triggered_by" => "user_1", "id" => UUID.uuid4()}
     iex> SwitchTrigger.changeset(%SwitchTrigger{}, params) |> Map.get(:valid?)
     true
  """
  def changeset(switch_trigger, params \\ %{}) do
    switch_trigger
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:switch_triggers_pkey, name: :switch_triggers_pkey)
    |> unique_constraint(:unique_request_token_for_switch_trigger,
      name: :unique_request_token_for_switch_trigger
    )
  end
end
