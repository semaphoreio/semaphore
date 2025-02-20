defmodule Ppl.Queues.Model.Queues do
  @moduledoc """
  Queues type

  Represents execution queue to which pipeline can belong. Queues are either
  implicitly defined (separate one for each label + yml_file combination in project),
  or the users define them (e.g. production, staging etc.) at wich point they
  can choose the scope of queue to be either project-wide or organization-wide.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:queue_id, :binary_id, autogenerate: false}
  schema "queues" do
    field :name,                :string
    field :user_generated,      :boolean, read_after_writes: true
    field :scope,               :string
    field :project_id,          :string
    field :organization_id,     :string

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(queue_id name scope project_id organization_id)a
  @optional_fields ~w(user_generated)a
  @valid_scopes ~w(project organization)


  @doc ~S"""
  ## Examples:

      iex> alias Ppl.Queues.Model.Queues
      iex> Queues.changeset(%Queues{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.Queues.Model.Queues
      iex> params = %{name: "production", scope: "project", project_id: UUID.uuid4,
      ...>   queue_id: UUID.uuid4, organization_id: UUID.uuid4, user_generated: true}
      iex> Queues.changeset(%Queues{}, params) |> Map.get(:valid?)
      true
  """
  def changeset(queue, params \\ %{}) do
    queue
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:scope, @valid_scopes)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:unique_queue_name_for_project,
                          name: :unique_queue_name_for_project)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:unique_queue_name_for_org,
                          name: :unique_queue_name_for_org)
  end
end
