defmodule Block.BlockSubppls.Model.BlockSubppls do
  @moduledoc """
  Block Subppl type
  Block Subppl execution request transitions through multiple states.
  Each transition is represented with 'block subppl' object.
  """

  alias Block.BlockRequests.Model.BlockRequests

  use Ecto.Schema

  import Ecto.Changeset

  schema "block_subppls" do
    belongs_to :block_requests, BlockRequests, [type: Ecto.UUID, foreign_key: :block_id]
    field :state, :string
    field :result, :string
    field :result_reason, :string
    field :subppl_file_path, :string
    field :subppl_id, Ecto.UUID
    field :block_subppl_index, :integer, read_after_writes: true
    field :in_scheduling, :boolean, read_after_writes: true
    field :recovery_count, :integer, read_after_writes: true
    field :terminate_request, :string
    field :terminate_request_desc, :string

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(block_id state in_scheduling subppl_file_path block_subppl_index)a
  @optional_fields ~w(result result_reason subppl_id recovery_count terminate_request terminate_request_desc)a
  @valid_states    ~w(pending running stopping done)
  @valid_results   ~w(passed failed stopped canceled)
  @valid_failed_result_reasons ~w(test malformed stuck)
  @valid_terminated_result_reasons ~w(user internal strategy fast_failing)
  @valid_terminate_requests  ~w(cancel stop)

  @doc ~S"""
  ## Examples:

      iex> alias Block.BlockSubppls.Model.BlockSubppls
      iex> BlockSubppls.changeset(%BlockSubppls{}) |> Map.get(:valid?)
      false

      iex> alias Block.BlockSubppls.Model.BlockSubppls
      iex> params1 = %{block_id: UUID.uuid1, state: "running", in_scheduling: false}
      iex> params2 = %{block_subppl_index: 0, subppl_file_path: "./semaphore.yml"}
      iex> params  = Map.merge(params1, params2)
      iex> BlockSubppls.changeset(%BlockSubppls{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(block_subppl_event, params \\ %{}) do
    block_subppl_event
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:result, @valid_results)
    |> validate_result_reason_field()
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
