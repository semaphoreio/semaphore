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
    field :branch, :string
    field :reference_type, :string, default: "branch"
    field :reference_value, :string
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

  @required_fields_insert ~w(periodic_id triggered_at project_id
                             pipeline_file scheduling_status recurring)a
  @optional_fields_insert ~w(branch reference_type reference_value run_now_requester_id)a

  @required_fields_update ~w(scheduling_status scheduled_at)a
  @optional_fields_update ~w(scheduled_workflow_id error_description attempts reference_type reference_value)a

  @valid_statuses ~w(running passed failed)

  @doc ~S"""
  ## Examples:

      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> PeriodicsTriggers.changeset_insert(%PeriodicsTriggers{}) |> Map.get(:valid?)
      false

      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> params = %{periodic_id: UUID.uuid1(), triggered_at: DateTime.utc_now(),
      ...>            branch: "master", project_id: "p1", pipeline_file: "deploy.yml",
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

  @doc """
  Returns the Git reference string for this trigger.
  
  ## Examples
  
      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> trigger = %PeriodicsTriggers{reference_type: "branch", reference_value: "main"}
      iex> PeriodicsTriggers.git_reference(trigger)
      "refs/heads/main"
      
      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> trigger = %PeriodicsTriggers{reference_type: "tag", reference_value: "v1.0.0"}
      iex> PeriodicsTriggers.git_reference(trigger)
      "refs/tags/v1.0.0"
  """
  def git_reference(%__MODULE__{reference_type: "branch", reference_value: reference_value}),
    do: "refs/heads/#{reference_value}"

  def git_reference(%__MODULE__{reference_type: "tag", reference_value: reference_value}),
    do: "refs/tags/#{reference_value}"

  # Handle maps (for backward compatibility when struct is converted to map)
  def git_reference(%{reference_type: "branch", reference_value: reference_value}),
    do: "refs/heads/#{reference_value}"

  def git_reference(%{reference_type: "tag", reference_value: reference_value}),
    do: "refs/tags/#{reference_value}"

  @doc """
  Backward compatibility getter for branch field.
  Returns reference_value when reference_type is :branch, otherwise nil.
  
  ## Examples
  
      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> trigger = %PeriodicsTriggers{reference_type: "branch", reference_value: "main"}
      iex> PeriodicsTriggers.branch_name(trigger)
      "main"
      
      iex> alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
      iex> trigger = %PeriodicsTriggers{reference_type: "tag", reference_value: "v1.0.0"}
      iex> PeriodicsTriggers.branch_name(trigger)
      nil
  """
  def branch_name(%__MODULE__{reference_type: "branch", reference_value: reference_value}),
    do: reference_value

  def branch_name(%__MODULE__{}), do: nil

  # Handle maps (for backward compatibility when struct is converted to map)
  def branch_name(%{reference_type: "branch", reference_value: reference_value}),
    do: reference_value

  def branch_name(%{}), do: nil
end
