defmodule Gofer.TargetTrigger.Model.TargetTrigger do
  @moduledoc """
  Represents one trigger of one of switch's targets.
  Holds data when was the target initated and and ppl_id of scheduled pipeline
  or error returned from Plumber if scheduling failed with :BAD_PARAM code.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Gofer.Switch.Model.Switch
  alias Gofer.SwitchTrigger.Model.SwitchTrigger

  @timestamps_opts type: :naive_datetime_usec
  schema "target_triggers" do
    belongs_to(:switches, Switch, type: Ecto.UUID, foreign_key: :switch_id)
    belongs_to(:switch_triggers, SwitchTrigger, type: Ecto.UUID, foreign_key: :switch_trigger_id)
    field(:target_name, :string)
    field(:scheduled_ppl_id, :string)
    field(:error_response, :string)
    field(:processed, :boolean, default: false)
    field(:processing_result, :string)
    field(:schedule_request_token, :string)
    field(:scheduled_at, :utc_datetime_usec)

    timestamps()
  end

  @required_fields ~w(switch_id switch_trigger_id target_name schedule_request_token)a
  @optional_fields ~w(scheduled_ppl_id error_response processed scheduled_at processing_result)a

  @doc """
  Examples:

     iex> alias Gofer.TargetTrigger.Model.TargetTrigger
     iex> TargetTrigger.changeset(%TargetTrigger{}) |> Map.get(:valid?)
     false

     iex> alias Gofer.TargetTrigger.Model.TargetTrigger
     iex> params = %{"switch_id" => UUID.uuid4(), "switch_trigger_id" => UUID.uuid4(),
     ...>            "schedule_request_token" => UUID.uuid4(), "target_name" => "stg"}
     iex> TargetTrigger.changeset(%TargetTrigger{}, params) |> Map.get(:valid?)
     true
  """
  def changeset(triggering, params \\ %{}) do
    triggering
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:one_target_trigger_per_tartget_per_switch_trigger,
      name: :one_target_trigger_per_tartget_per_switch_trigger
    )
  end
end
