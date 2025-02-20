defmodule Ppl.TimeLimits.Model.TimeLimits do
  @moduledoc """
  TimeLimits are used to ensure that pipeline or block does not run longer than
  its execution time limit.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ppl.PplRequests.Model.PplRequests

  schema "time_limits" do
    belongs_to :pipeline_requests, PplRequests, [type: Ecto.UUID, foreign_key: :ppl_id]
    field :deadline, :utc_datetime_usec
    field :type, :string
    field :block_index, :integer, read_after_writes: true
    field :state, :string
    field :result, :string
    field :result_reason, :string
    field :in_scheduling, :boolean, read_after_writes: true
    field :error_description, :string
    field :recovery_count, :integer, read_after_writes: true
    field :terminate_request, :string
    field :terminate_request_desc, :string

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(ppl_id state in_scheduling type deadline)a
  @optional_fields ~w(result result_reason error_description recovery_count
                      terminate_request terminate_request_desc block_index)a
  @valid_types     ~w(pipeline ppl_block)
  @valid_states    ~w(tracking done)
  @valid_results   ~w(enforced canceled)

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.TimeLimits.Model.TimeLimits
      iex> TimeLimits.changeset(%TimeLimits{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.TimeLimits.Model.TimeLimits
      iex> params = %{ppl_id: UUID.uuid1, state: "tracking", in_scheduling: false,
      iex>            type: "pipeline", deadline: DateTime.utc_now()}
      iex> TimeLimits.changeset(%TimeLimits{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(tl, params \\ %{}) do
    tl
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:result, @valid_results)
    |> validate_block_index()
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_limit_per_ppl_or_block, name: :one_limit_per_ppl_or_block)
  end

  defp validate_block_index(changeset) do
    changeset
    |> get_field(:type)
    |> validate_block_index_(changeset)
  end

  defp validate_block_index_("ppl_block", changeset) do
    validate_required(changeset, :block_index)
  end
  defp validate_block_index_(_other, changeset), do: changeset
end
