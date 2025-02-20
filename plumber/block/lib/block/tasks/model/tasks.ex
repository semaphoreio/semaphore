defmodule Block.Tasks.Model.Tasks do
  @moduledoc """
  Tasks type
  Task execution request transitions through multiple states.
  Each transition is represented with 'task' object.
  """

  alias Block.BlockRequests.Model.BlockRequests

  use Ecto.Schema

  import Ecto.Changeset

  schema "block_builds" do
    belongs_to :block_requests, BlockRequests, [type: Ecto.UUID, foreign_key: :block_id]
    field :build_request_id, Ecto.UUID
    field :state, :string
    field :result, :string
    field :result_reason, :string
    field :description, :map
    field :in_scheduling, :boolean, read_after_writes: true
    field :recovery_count, :integer, read_after_writes: true
    field :terminate_request, :string
    field :terminate_request_desc, :string
    field :task_id, :string

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(block_id state in_scheduling)a
  @optional_fields ~w(result result_reason description build_request_id recovery_count
                      terminate_request terminate_request_desc task_id)a
  @valid_states    ~w(pending running stopping done)
  @valid_results   ~w(passed failed stopped canceled)
  @valid_failed_result_reasons ~w(test malformed stuck)
  @valid_terminated_result_reasons ~w(user internal strategy fast_failing deleted)
  @valid_terminate_requests  ~w(cancel stop)

  @doc ~S"""
  ## Examples:

      iex> alias Block.Tasks.Model.Tasks
      iex> Tasks.changeset(%Tasks{}) |> Map.get(:valid?)
      false

      iex> alias Block.Tasks.Model.Tasks
      iex> params1 = %{block_id: UUID.uuid1, state: "running"}
      iex> params2 = %{build_request_id: UUID.uuid1, in_scheduling: false}
      iex> params  = Map.merge(params1, params2)
      iex> Tasks.changeset(%Tasks{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(task, params \\ %{}) do
    task
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
