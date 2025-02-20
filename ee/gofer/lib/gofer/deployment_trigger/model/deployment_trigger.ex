defmodule Gofer.DeploymentTrigger.Model.DeploymentTrigger do
  @moduledoc """
  Stores deployment target trigger and its status data
  """
  use Ecto.Schema

  @states ~w(INITIALIZING TRIGGERING STARTING DONE)a
  @required_fields ~w(
    deployment_id switch_id triggered_by triggered_at state git_ref_type git_ref_label
    switch_trigger_id target_name request_token switch_trigger_params
  )a
  @all_fields ~w(
    deployment_id switch_id triggered_by triggered_at git_ref_type git_ref_label
    switch_trigger_id target_name request_token switch_trigger_params
    parameter1 parameter2 parameter3 scheduled_at pipeline_id state result reason
  )a

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts type: :naive_datetime_usec
  schema "deployment_triggers" do
    belongs_to(:deployment, Gofer.Deployment.Model.Deployment,
      type: Ecto.UUID,
      foreign_key: :deployment_id
    )

    belongs_to(:switch, Gofer.Switch.Model.Switch,
      type: Ecto.UUID,
      foreign_key: :switch_id
    )

    field(:triggered_by, :string)
    field(:triggered_at, :utc_datetime_usec)

    field(:git_ref_type, :string)
    field(:git_ref_label, :string)

    field(:switch_trigger_id, :string)
    field(:target_name, :string)
    field(:request_token, :string)
    field(:switch_trigger_params, :map)

    field(:scheduled_at, :utc_datetime_usec)
    field(:pipeline_id, :string)

    field(:parameter1, :string)
    field(:parameter2, :string)
    field(:parameter3, :string)

    field(:state, Ecto.Enum,
      values: @states,
      default: :INITIALIZING
    )

    field(:result, :string)
    field(:reason, :string)

    timestamps()
  end

  def changeset(trigger, params) do
    trigger
    |> Ecto.Changeset.cast(params, @all_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
    |> Ecto.Changeset.foreign_key_constraint(:deployment_id)
    |> Ecto.Changeset.foreign_key_constraint(:switch_id)
    |> Ecto.Changeset.unique_constraint(:request_token,
      name: :unique_deployment_trigger_per_request_token
    )
    |> Ecto.Changeset.unique_constraint(:target_name,
      name: :unique_deployment_trigger_per_target_trigger
    )
  end
end
