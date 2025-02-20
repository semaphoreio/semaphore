defmodule Gofer.Target.Model.Target do
  @moduledoc """
  Represents switch target.
  Each target must have unique name, stores data about path to file which contains
  definition of pipeline which needs to be scheduled on trigger event,
  and target can be auto triggered when one of conditions from auto_trigger_on is met.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Gofer.Switch.Model.Switch

  @timestamps_opts type: :naive_datetime_usec
  schema "targets" do
    belongs_to(:switches, Switch, type: Ecto.UUID, foreign_key: :switch_id)
    field(:name, :string)
    field(:pipeline_path, :string)
    field(:parameter_env_vars, :map)
    field(:auto_trigger_on, {:array, :map})
    field(:auto_promote_when, :string)
    field(:deployment_target, :string)

    timestamps()
  end

  @required_fields ~w(switch_id name pipeline_path)a
  @optional_fields ~w(auto_trigger_on parameter_env_vars auto_promote_when deployment_target)a

  @doc ~S"""
  ## Examples:

      iex> alias Gofer.Target.Model.Target
      iex> Target.changeset(%Target{}) |> Map.get(:valid?)
      false

      iex> alias Gofer.Target.Model.Target
      iex> params = %{switch_id: UUID.uuid1, name: "staging", pipeline_path: "./staging.yml"}
      iex> Target.changeset(%Target{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(target, params \\ %{}) do
    target
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:uniqe_target_name_per_switch, name: :uniqe_target_name_per_switch)
  end
end
