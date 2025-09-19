defmodule Scheduler.Periodics.Model.Periodics do
  @moduledoc """
  Periodic type

  Each distinct request from user to periodically schedule a workflow is modeled
  with Periodic type.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :naive_datetime_usec]
  schema "periodics" do
    field :requester_id, :string
    field :organization_id, :string
    field :name, :string
    field :description, :string
    field :project_name, :string
    field :project_id, :string
    field :reference, :string, source: :branch
    field :at, :string
    field :pipeline_file, :string
    field :recurring, :boolean, read_after_writes: true, default: true
    field :suspended, :boolean, read_after_writes: true
    field :paused, :boolean, read_after_writes: true, default: false
    field :pause_toggled_by, :string, read_after_writes: true, default: ""
    field :pause_toggled_at, :utc_datetime_usec, read_after_writes: true

    embeds_many :parameters, Scheduler.Periodics.Model.PeriodicsParam, on_replace: :delete

    timestamps()
  end

  @required_fields_v1_0 ~w(id requester_id organization_id name project_name
                          project_id reference at pipeline_file)a
  @optional_fields_v1_0 ~w(paused pause_toggled_by pause_toggled_at)a

  @required_fields_update_v1_0 ~w(requester_id organization_id)a
  @optional_fields_update_v1_0 ~w(name project_name project_id reference at pipeline_file
                                 suspended paused pause_toggled_by pause_toggled_at)a

  @required_fields ~w(id requester_id organization_id name project_name
                      project_id recurring reference pipeline_file)a
  @optional_fields ~w(description at paused pause_toggled_by pause_toggled_at)a

  @required_fields_update ~w(requester_id organization_id)a
  @optional_fields_update ~w(name project_name project_id reference at pipeline_file recurring
                             description suspended paused pause_toggled_by pause_toggled_at)a

  @doc """
  ## Examples:

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> alias Scheduler.Periodics.Model.PeriodicsParam, as: Param
      iex> Periodics.default_parameter_values(%Periodics{
      ...>   parameters: [
      ...>     %Param{name: "p1", required: true, options: [], default_value: "v1"},
      ...>     %Param{name: "p2", required: false, options: [], default_value: "v2"},
      ...>     %Param{name: "p3", required: true, options: ["v1", "v2"], default_value: "v3"},
      ...>     %Param{name: "p4", required: false, options: ["v1", "v2"]},
      ...>   ]
      ...> })
      [%{name: "p1", value: "v1"}, %{name: "p2", value: "v2"}, %{name: "p3", value: "v3"}]
  """
  def default_parameter_values(periodic) do
    periodic.parameters
    |> Enum.into([], &%{name: &1.name, value: &1.default_value || ""})
    |> Enum.reject(&String.equivalent?(&1.value, ""))
  end

  @doc ~S"""
  ## Examples:

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> Periodics.changeset(%Periodics{}, "v1.0") |> Map.get(:valid?)
      false

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> params = %{requester_id: UUID.uuid1(), organization_id: UUID.uuid1(),
      ...>           name: "P1", project_name: "Pr1", reference: "master", project_id: "p1",
      ...>           at: "* * * * *", id: UUID.uuid1(), pipeline_file: "deploy.yml"}
      iex> Periodics.changeset(%Periodics{}, "v1.0", params) |> Map.get(:valid?)
      true

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> params = %{requester_id: UUID.uuid1(), organization_id: UUID.uuid1(), id: UUID.uuid1(),
      ...>           name: "P1", project_name: "Pr1", project_id: "p1",
      ...>           reference: "master", pipeline_file: "deploy.yml", recurring: false,
      ...>           parameters: [%{name: "foo", required: true, default_value: "bar"}]}
      iex> Periodics.changeset(%Periodics{}, "v1.1", params) |> Map.get(:valid?)
      true
  """
  def changeset(periodic, api_version, params \\ %{})

  def changeset(periodic, api_version = "v1.0", params) do
    do_changeset(periodic, params, api_version, @required_fields_v1_0, @optional_fields_v1_0)
  end

  def changeset(periodic, api_version = "v1.1", params) do
    do_changeset(periodic, params, api_version, @required_fields, @optional_fields)
  end

  def changeset(periodic, api_version = "v1.2", params) do
    do_changeset(periodic, params, api_version, @required_fields, @optional_fields)
  end

  @doc ~S"""
  ## Examples:

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> Periodics.changeset_update(%Periodics{}, "v1.0") |> Map.get(:valid?)
      false

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> params = %{requester_id: UUID.uuid1(), organization_id: UUID.uuid1(), at: "* * * * *",
      ...>           name: "P1",  reference: "master", pipeline_file: "deploy.yml"}
      iex> Periodics.changeset_update(%Periodics{}, "v1.0", params) |> Map.get(:valid?)
      true

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> params = %{requester_id: UUID.uuid1(), organization_id: UUID.uuid1(), name: "P1", recurring: false}
      iex> Periodics.changeset_update(%Periodics{}, "v1.1", params) |> Map.get(:valid?)
      true
  """
  def changeset_update(periodic, api_version, params \\ %{})

  def changeset_update(periodic, api_version = "v1.0", params) do
    do_changeset(
      periodic,
      params,
      api_version,
      @required_fields_update_v1_0,
      @optional_fields_update_v1_0
    )
  end

  def changeset_update(periodic, api_version = "v1.1", params) do
    do_changeset(periodic, params, api_version, @required_fields_update, @optional_fields_update)
  end

  def changeset_update(periodic, api_version = "v1.2", params) do
    do_changeset(periodic, params, api_version, @required_fields_update, @optional_fields_update)
  end

  defp do_changeset(periodic, params, api_version, required_fields, optional_fields) do
    periodic
    |> cast(params, required_fields ++ optional_fields)
    |> maybe_cast_parameters(api_version)
    |> validate_required(required_fields)
    |> validate_recurring(api_version)
    |> validate_change(:at, &validate_cron/2)
    |> unique_constraint(:unique_project_id_and_name, name: :project_id_and_name_unique_index)
  end

  defp maybe_cast_parameters(changeset, "v1.0"), do: changeset
  defp maybe_cast_parameters(changeset, "v1.1"), do: cast_embed(changeset, :parameters)
  defp maybe_cast_parameters(changeset, "v1.2"), do: cast_embed(changeset, :parameters)

  defp validate_recurring(changeset, "v1.0") do
    changeset
    |> put_change(:recurring, true)
    |> validate_inclusion(:recurring, [true])
    |> validate_required(~w(at reference pipeline_file)a)
  end

  defp validate_recurring(changeset, "v1.1"),
    do: validate_recurring(changeset, "v1.1", get_field(changeset, :recurring))

  defp validate_recurring(changeset, "v1.2"),
    do: validate_recurring(changeset, "v1.2", get_field(changeset, :recurring))

  defp validate_recurring(changeset, "v1.1", true), do: validate_required(changeset, [:at])
  defp validate_recurring(changeset, "v1.1", false), do: changeset

  defp validate_recurring(changeset, "v1.2", true), do: validate_required(changeset, [:at])
  defp validate_recurring(changeset, "v1.2", false), do: changeset

  defp validate_cron(_field_name, cron_expression) do
    case Crontab.CronExpression.Parser.parse(cron_expression) do
      {:ok, %Crontab.CronExpression{}} -> []
      {:error, _message} -> [at: "is not a valid cron expression"]
    end
  end
end
