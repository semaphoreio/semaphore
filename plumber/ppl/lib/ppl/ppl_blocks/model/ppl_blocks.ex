defmodule Ppl.PplBlocks.Model.PplBlocks do
  @moduledoc """
  Pipeline Blocks type
  When Pipeline goes from 'initializing' to waiting, one Pipeline Block
  is created fore each pipeline's block, and it serves to track each blocks
  transitions through multiple states.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.PplBlocks.Model.PplBlockConnections

  schema "pipeline_blocks" do
    belongs_to :pipeline_requests, PplRequests, [type: Ecto.UUID, foreign_key: :ppl_id]
    field :name, :string
    field :state, :string
    field :result, :string
    field :result_reason, :string
    field :error_description, :string
    field :duplicate, :boolean, read_after_writes: true
    field :block_id, Ecto.UUID
    field :block_index, :integer, read_after_writes: true
    field :in_scheduling, :boolean, read_after_writes: true
    field :recovery_count, :integer, read_after_writes: true
    field :terminate_request, :string
    field :terminate_request_desc, :string
    field :exec_time_limit_min, :integer
    field :priority, :integer

    has_many :connections, PplBlockConnections, foreign_key: :target

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(ppl_id name block_index state  in_scheduling)a
  @optional_fields ~w(block_id result result_reason error_description duplicate
                      recovery_count terminate_request terminate_request_desc
                      exec_time_limit_min priority)a
  @valid_states    ~w(initializing waiting running stopping done)
  @valid_results   ~w(passed failed stopped canceled)
  @valid_failed_result_reasons ~w(test malformed stuck)
  @valid_terminated_result_reasons ~w(user internal strategy fast_failing deleted)
  @valid_terminate_requests  ~w(cancel stop)

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplBlocks.Model.PplBlocks
      iex> PplBlocks.changeset(%PplBlocks{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplBlocks.Model.PplBlocks
      iex> params1 = %{ppl_id: UUID.uuid1, name: "blk_1", state: "running"}
      iex> params2 = %{block_index: 1, in_scheduling: false}
      iex> params  = Map.merge(params1, params2)
      iex> PplBlocks.changeset(%PplBlocks{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(ppl_blk, params \\ %{}) do
    ppl_blk
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:result, @valid_results)
    |> validate_result_reason_field()
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:unique_ppl_id_and_block_index, name: :ppl_id_and_block_index_unique_index)
    |> unique_constraint(:unique_ppl_id_and_name, name: :ppl_id_and_name_unique_index)
    |> validate_terminate_request_field()
  end

  defp validate_result_reason_field(changeset) do
    changeset
    |> get_field(:result)
    |> validate_result_reason_field_(changeset)
  end

  defp validate_result_reason_field_("failed", changeset) do
    validate_inclusion(changeset, :result_reason, @valid_failed_result_reasons)
  end
  defp validate_result_reason_field_(state, changeset) when state in ["stopped", "canceled"] do
    validate_inclusion(changeset, :result_reason, @valid_terminated_result_reasons)
  end
  defp validate_result_reason_field_(_other, changeset), do: changeset

  defp validate_terminate_request_field(changeset) do
    changeset
    |> get_field(:terminate_request)
    |> validate_terminate_request_field_(changeset)
  end

  defp validate_terminate_request_field_(nil, changeset), do: changeset
  defp validate_terminate_request_field_(_value, changeset) do
    validate_inclusion(changeset, :terminate_request, @valid_terminate_requests)
  end
end
