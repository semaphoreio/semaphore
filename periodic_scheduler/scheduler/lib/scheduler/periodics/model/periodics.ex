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
    field :branch, :string
    field :reference_type, :string, default: "branch"
    field :reference_value, :string
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
                          project_id branch at pipeline_file)a
  @optional_fields_v1_0 ~w(paused pause_toggled_by pause_toggled_at)a

  @required_fields_update_v1_0 ~w(requester_id organization_id)a
  @optional_fields_update_v1_0 ~w(name project_name project_id branch at pipeline_file
                                 suspended paused pause_toggled_by pause_toggled_at)a

  @required_fields ~w(id requester_id organization_id name project_name
                      project_id recurring pipeline_file)a
  @optional_fields ~w(description at branch reference_type reference_value paused pause_toggled_by pause_toggled_at)a

  @required_fields_update ~w(requester_id organization_id)a
  @optional_fields_update ~w(name project_name project_id branch reference_type reference_value at pipeline_file recurring
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
      ...>           name: "P1", project_name: "Pr1", branch: "master", project_id: "p1",
      ...>           at: "* * * * *", id: UUID.uuid1(), pipeline_file: "deploy.yml"}
      iex> Periodics.changeset(%Periodics{}, "v1.0", params) |> Map.get(:valid?)
      true

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> params = %{requester_id: UUID.uuid1(), organization_id: UUID.uuid1(), id: UUID.uuid1(),
      ...>           name: "P1", project_name: "Pr1", project_id: "p1",
      ...>           branch: "master", pipeline_file: "deploy.yml", recurring: false,
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

  @doc ~S"""
  ## Examples:

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> Periodics.changeset_update(%Periodics{}, "v1.0") |> Map.get(:valid?)
      false

      iex> alias Scheduler.Periodics.Model.Periodics
      iex> params = %{requester_id: UUID.uuid1(), organization_id: UUID.uuid1(), at: "* * * * *",
      ...>           name: "P1",  branch: "master", pipeline_file: "deploy.yml"}
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

  defp do_changeset(periodic, params, api_version, required_fields, optional_fields) do
    periodic
    |> cast(params, required_fields ++ optional_fields)
    |> handle_backward_compatibility_for_branch()
    |> maybe_cast_parameters(api_version)
    |> validate_required(required_fields)
    |> validate_recurring(api_version)
    |> validate_change(:at, &validate_cron/2)
    |> unique_constraint(:unique_project_id_and_name, name: :project_id_and_name_unique_index)
  end

  defp maybe_cast_parameters(changeset, "v1.0"), do: changeset
  defp maybe_cast_parameters(changeset, "v1.1"), do: cast_embed(changeset, :parameters)

  defp validate_recurring(changeset, "v1.0") do
    changeset
    |> put_change(:recurring, true)
    |> validate_inclusion(:recurring, [true])
    |> validate_required(~w(at branch pipeline_file)a)
  end

  defp validate_recurring(changeset, "v1.1"),
    do: validate_recurring(changeset, "v1.1", get_field(changeset, :recurring))

  defp validate_recurring(changeset, "v1.1", true) do
    changeset
    |> validate_required([:at, :pipeline_file])
    |> validate_reference_fields()
  end

  defp validate_reference_fields(changeset) do
    branch_value = get_change(changeset, :branch) || get_field(changeset, :branch)
    reference_type = get_change(changeset, :reference_type) || get_field(changeset, :reference_type)
    reference_value = get_change(changeset, :reference_value) || get_field(changeset, :reference_value)

    case {branch_value, reference_type, reference_value} do
      {branch, _, _} when is_binary(branch) and branch != "" ->
        changeset
      {_, type, value} when is_binary(type) and is_binary(value) and type != "" and value != "" ->
        changeset
      _ ->
        add_error(changeset, :branch, "can't be blank")
    end
  end
  
  defp validate_recurring(changeset, "v1.1", false), do: changeset

  defp handle_backward_compatibility_for_branch(changeset) do
    branch_value = get_change(changeset, :branch)
    reference_type = get_change(changeset, :reference_type) || get_field(changeset, :reference_type)
    reference_value = get_change(changeset, :reference_value)

    case {branch_value, reference_type, reference_value} do
      # If branch is provided but reference fields are not, migrate branch to reference fields
      {branch, nil, nil} when is_binary(branch) ->
        changeset
        |> put_change(:reference_type, "branch")
        |> put_change(:reference_value, branch)
        
      {branch, "branch", nil} when is_binary(branch) ->
        changeset
        |> put_change(:reference_value, branch)

      # If both branch and reference_value are provided, prefer reference_value
      {_branch, _type, reference} when is_binary(reference) ->
        changeset

      # If we have reference fields, ensure they're valid
      {_branch, type, value} when is_binary(type) and is_binary(value) ->
        changeset

      # Default case - no changes needed
      _ ->
        changeset
    end
  end

  defp validate_cron(_field_name, cron_expression) do
    case Crontab.CronExpression.Parser.parse(cron_expression) do
      {:ok, %Crontab.CronExpression{}} -> []
      {:error, _message} -> [at: "is not a valid cron expression"]
    end
  end

  @doc """
  Returns the Git reference string for this periodic.
  
  ## Examples
  
      iex> alias Scheduler.Periodics.Model.Periodics
      iex> periodic = %Periodics{reference_type: "branch", reference_value: "main"}
      iex> Periodics.git_reference(periodic)
      "refs/heads/main"
      
      iex> alias Scheduler.Periodics.Model.Periodics
      iex> periodic = %Periodics{reference_type: "tag", reference_value: "v1.0.0"}
      iex> Periodics.git_reference(periodic)
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
  
      iex> alias Scheduler.Periodics.Model.Periodics
      iex> periodic = %Periodics{reference_type: "branch", reference_value: "main"}
      iex> Periodics.branch_name(periodic)
      "main"
      
      iex> alias Scheduler.Periodics.Model.Periodics
      iex> periodic = %Periodics{reference_type: "tag", reference_value: "v1.0.0"}
      iex> Periodics.branch_name(periodic)
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
