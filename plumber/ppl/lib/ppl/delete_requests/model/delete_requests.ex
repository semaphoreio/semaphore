defmodule Ppl.DeleteRequests.Model.DeleteRequests do
  @moduledoc """
  DeleteRequests stores received delete requests and serves for tracking their execution.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "delete_requests" do
    field :project_id, :string
    field :requester, :string
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


  @required_fields ~w(state in_scheduling project_id requester)a
  @optional_fields ~w(result result_reason error_description recovery_count
                      terminate_request terminate_request_desc)a
  @valid_states    ~w(pending deleting queue_deleting done)
  @valid_results   ~w(passed failed)
  @valid_failed_result_reasons ~w(stuck internal)

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.DeleteRequests.Model.DeleteRequests
      iex> DeleteRequests.changeset(%DeleteRequests{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.DeleteRequests.Model.DeleteRequests
      iex> params = %{project_id: UUID.uuid1, requester: UUID.uuid1, state: "pending",
      ...>           in_scheduling: false}
      iex> DeleteRequests.changeset(%DeleteRequests{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(delete_request, params \\ %{}) do
    delete_request
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:result, @valid_results)
    |> validate_result_reason_field()
  end

  defp validate_result_reason_field(changeset) do
    changeset
    |> get_field(:result)
    |> validate_result_reason_field_(changeset)
  end

  defp validate_result_reason_field_("failed", changeset) do
    validate_inclusion(changeset, :result_reason, @valid_failed_result_reasons)
  end
  defp validate_result_reason_field_(_other, changeset), do: changeset
end
