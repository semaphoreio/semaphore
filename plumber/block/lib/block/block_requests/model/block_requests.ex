defmodule Block.BlockRequests.Model.BlockRequests do
  @moduledoc """
  BlockRequests type
  Each pipeline block is represented with 'block_request' object (database row).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "block_requests" do

    field :definition, :map
    field :request_args, :map
    field :build, :map
    field :ppl_id, Ecto.UUID
    field :hook_id, :string
    field :version, :string
    field :pple_block_index, :integer
    field :has_build?, :boolean
    field :subppl_count, :integer, read_after_writes: true
    field :source_args, :map

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields_request ~w(ppl_id pple_block_index request_args hook_id version definition)a
  @optional_fields_request ~w(source_args)a
  @required_fields_build ~w(build)a

  def changeset_request(block_req, params \\ %{}) do
    block_req
    |> cast(params, @required_fields_request ++ @optional_fields_request)
    |> validate_required(@required_fields_request)
    |> validate_definition__build_required?()
    |> validate_definition__includes_allowed?()
    |> force_change(:has_build?, has_build?(params))
    |> force_change(:subppl_count, get_subppl_count(params))
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:ppl_id_and_blk_ind_unique_index, name: :ppl_id_and_blk_ind_unique_index)
  end

  defp has_build?(params), do: get_in(params, [:definition, "build"]) != nil

  defp get_subppl_count(block_req) do
    (get_in(block_req, [:definition, "includes"]) || []) |> length()
  end

  defp validate_definition__build_required?(changeset) do
    changes = Map.get(changeset, :changes)
    version = Map.get(changes, :version)
    validate_change(changeset, :definition, fn(_field, value) -> definition_field_validator__required_build(version, value) end)
  end

  def definition_field_validator__required_build(version, definition) do
    v1? = version == "v1.0"
    build_present? = Map.get(definition, "build", nil) != nil
    build_required_and_present?(v1?, build_present?)
  end
  defp build_required_and_present?(true, false), do: [definition: "Definition must contain 'build' field when pipeline version is v1.0"]
  defp build_required_and_present?(_, _), do: []

  defp validate_definition__includes_allowed?(changeset) do
    changes = Map.get(changeset, :changes)
    version = Map.get(changes, :version)
    validate_change(changeset, :definition, fn(_field, value) -> definition_field_validator__includes_allowed(version, value) end)
  end

  def definition_field_validator__includes_allowed(version, value) do
    v1? = version == "v1.0"
    includes_present? = Map.get(value, "includes", nil) != nil
    includes_forbidden_and_present?(v1?, includes_present?)
  end
  defp includes_forbidden_and_present?(true, true), do: [definition: "Definition can not contain 'includes' field when pipeline version is v1.0"]
  defp includes_forbidden_and_present?(_, _), do: []

  @doc ~S"""
  ## Examples:

      iex> alias Block.BlockRequests.Model.BlockRequests
      iex> definition = %{}
      iex> BlockRequests.changeset_build(%BlockRequests{definition: definition}, %{}) |> Map.get(:valid?)
      false

      iex> alias Block.BlockRequests.Model.BlockRequests
      iex> definition = %{}
      iex> build = %{"jobs" => []}
      iex> changeset = %{build: build}
      iex> BlockRequests.changeset_build(%BlockRequests{definition: definition}, changeset) |> Map.get(:valid?)
      true
  """
  def changeset_build(block_req, params \\ %{}) do
    block_req
    |> cast(params, @required_fields_build)
    |> validate_required(@required_fields_build)
  end


  def changeset_duplicate(block_req, params \\ %{}) do
    block_req
    |> cast(params, @required_fields_request ++ @required_fields_build ++ [:has_build?, :subppl_count])
    |> validate_required(@required_fields_request ++ @required_fields_build)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:ppl_id_and_blk_ind_unique_index, name: :ppl_id_and_blk_ind_unique_index)
  end
end
