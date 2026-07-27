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

  # `queues.name` is a Postgres `varchar(255)`, whose limit is counted in
  # Unicode codepoints (not bytes or graphemes).
  @max_name_length 255
  # Number of hex chars of the sha256 suffix appended when a name is shortened.
  @name_hash_length 16


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
    |> validate_name_length()
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:unique_queue_name_for_project,
                          name: :unique_queue_name_for_project)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:unique_queue_name_for_org,
                          name: :unique_queue_name_for_org)
  end

  @doc """
  Largest queue name the `name` column can store, counted in Unicode codepoints.
  """
  def max_name_length, do: @max_name_length

  @doc ~S"""
  Returns a queue name guaranteed to fit the `varchar(255)` `name` column.

  Names within the limit are returned unchanged. Longer names - e.g. an implicit
  queue named after a very long branch or tag (`"<label>-<yml_file_path>"`) - are
  deterministically shortened to a readable prefix plus a hash of the full name.
  Hashing keeps distinct long names in distinct queues; plain truncation would
  collide names that share a prefix and wrongly serialize unrelated pipelines.

  ## Examples:

      iex> Ppl.Queues.Model.Queues.safe_name("master-.semaphore/semaphore.yml")
      "master-.semaphore/semaphore.yml"

      iex> name = String.duplicate("a", 300)
      iex> safe = Ppl.Queues.Model.Queues.safe_name(name)
      iex> String.length(safe)
      255
      iex> safe == Ppl.Queues.Model.Queues.safe_name(name)
      true
  """
  def safe_name(name) when is_binary(name) do
    cond do
      # Fast path: a codepoint is >= 1 byte, so byte_size <= limit => within limit.
      byte_size(name) <= @max_name_length -> name
      codepoint_count(name) <= @max_name_length -> name
      true -> shorten_name(name)
    end
  end

  defp shorten_name(name) do
    hash =
      :crypto.hash(:sha256, name)
      |> Base.encode16(case: :lower)
      |> binary_part(0, @name_hash_length)

    prefix =
      name
      |> String.codepoints()
      |> Enum.take(@max_name_length - @name_hash_length - 1)
      |> Enum.join()

    "#{prefix}-#{hash}"
  end

  defp validate_name_length(changeset) do
    validate_change(changeset, :name, fn :name, name ->
      if codepoint_count(name) <= @max_name_length do
        []
      else
        [name: {"should be at most %{count} character(s)",
                count: @max_name_length, validation: :length, kind: :max, type: :string}]
      end
    end)
  end

  defp codepoint_count(name), do: name |> String.codepoints() |> length()
end
