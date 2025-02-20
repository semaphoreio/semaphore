defmodule Gofer.Switch.Model.Switch do
  @moduledoc """
  Represents pipeline's switch.
  Switch serves to automatically initiates one or more pipelines when given pipeline finishes
  with result: "passed".
  It also exposes API for manual pipeline scheduling.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :naive_datetime_usec]
  schema "switches" do
    field(:ppl_id, :string)
    field(:branch_name, :string)
    field(:prev_ppl_artefact_ids, {:array, :string})
    field(:ppl_done, :boolean)
    field(:ppl_result, :string)
    field(:ppl_result_reason, :string)
    field(:label, :string)
    field(:git_ref_type, :string)
    field(:project_id, :string)
    field(:commit_sha, :string)
    field(:working_dir, :string)
    field(:commit_range, :string)
    field(:yml_file_name, :string)
    field(:pr_base, :string)
    field(:pr_sha, :string)

    timestamps()
  end

  @required_fields ~w(id ppl_id prev_ppl_artefact_ids branch_name)a
  @optional_fields ~w(label git_ref_type project_id commit_sha working_dir
                      commit_range yml_file_name pr_base pr_sha)a
  @required_fields_update ~w(ppl_done ppl_result)a
  @optional_fields_update ~w(ppl_result_reason)a

  @doc ~S"""
  ## Examples:

      iex> alias Gofer.Switch.Model.Switch
      iex> Switch.changeset(%Switch{}) |> Map.get(:valid?)
      false

      iex> alias Gofer.Switch.Model.Switch
      iex> params = %{"id" => UUID.uuid4(), "ppl_id" => UUID.uuid4(),
      ...>            "prev_ppl_artefact_ids" => [], "branch_name" => "master"}
      iex> Switch.changeset(%Switch{}, params) |> Map.get(:valid?)
      true
  """
  def changeset(switch, params \\ %{}) do
    switch
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:switches_pkey, name: :switches_pkey)
    |> unique_constraint(:unique_ppl_id_for_switch, name: :unique_ppl_id_for_switch)
  end

  @doc ~S"""
  ## Examples:

      iex> alias Gofer.Switch.Model.Switch
      iex> Switch.changeset(%Switch{}) |> Map.get(:valid?)
      false

      iex> alias Gofer.Switch.Model.Switch
      iex> params = %{"ppl_done" => true, "ppl_result" => "passed"}
      iex> Switch.changeset_update(%Switch{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_update(switch, params \\ %{}) do
    switch
    |> cast(params, @required_fields_update ++ @optional_fields_update)
    |> validate_required(@required_fields_update)
  end
end
