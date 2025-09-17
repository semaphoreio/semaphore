defmodule Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers do
  @moduledoc """
  Periodics Triggers type

  Each scheduling atempt, no mather of it's result, for each periodic is modeled
  with PeriodicsTrigger type.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersParam
  alias Scheduler.Periodics.Model.Periodics

  @timestamps_opts [type: :naive_datetime_usec]
  schema "periodics_triggers" do
    belongs_to :periodics, Periodics, type: Ecto.UUID, foreign_key: :periodic_id
    field :triggered_at, :utc_datetime_usec
    field :project_id, :string
    field :reference, :string
    field :pipeline_file, :string
    field :scheduling_status, :string
    field :recurring, :boolean
    field :run_now_requester_id, :string, read_after_writes: true
    field :scheduled_workflow_id, :string, read_after_writes: true
    field :scheduled_at, :utc_datetime_usec
    field :error_description, :string, read_after_writes: true
    field :attempts, :integer, default: 0
    embeds_many :parameter_values, PeriodicsTriggersParam, on_replace: :delete

    timestamps()
  end

  @required_fields_insert ~w(periodic_id triggered_at project_id reference
                             pipeline_file scheduling_status recurring)a
  @optional_fields_insert ~w(run_now_requester_id)a

  @required_fields_update ~w(scheduling_status scheduled_at)a
  @optional_fields_update ~w(scheduled_workflow_id error_description attempts)a

  @valid_statuses ~w(running passed failed)

  @doc ~S"""
  ## Examples:

      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> PeriodicsTriggers.changeset_insert(%PeriodicsTriggers{}) |> Map.get(:valid?)
      false

      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> params = %{periodic_id: UUID.uuid1(), triggered_at: DateTime.utc_now(),
      ...>            reference: "master", project_id: "p1", pipeline_file: "deploy.yml",
      ...>            scheduling_status: "running", recurring: true,
      ...>            parameter_values: [%{name: "p1", value: "v1"}]}
      iex> PeriodicsTriggers.changeset_insert(%PeriodicsTriggers{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_insert(trigger, params \\ %{}) do
    trigger
    |> cast(params, @required_fields_insert ++ @optional_fields_insert)
    |> cast_embed(:parameter_values)
    |> validate_required(@required_fields_insert)
    |> validate_inclusion(:scheduling_status, @valid_statuses)
  end

  @doc ~S"""
  ## Examples:

      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> PeriodicsTriggers.changeset_update(%PeriodicsTriggers{}) |> Map.get(:valid?)
      false

      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> params = %{scheduling_status: "passed", scheduled_at: DateTime.utc_now(),
      ...>            scheduled_workflow_id: UUID.uuid1(), attempts: 1}
      iex> PeriodicsTriggers.changeset_update(%PeriodicsTriggers{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_update(trigger, params \\ %{}) do
    trigger
    |> cast(params, @required_fields_update ++ @optional_fields_update)
    |> validate_required(@required_fields_update)
    |> validate_inclusion(:scheduling_status, @valid_statuses)
  end
end
