defmodule Ppl.AfterPplTasks.Model.AfterPplTasks do
  @moduledoc """
  AfterPplTasks type
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ppl.PplRequests.Model.PplRequests

  schema "after_ppl_tasks" do
    belongs_to(:pipeline_requests, PplRequests, type: Ecto.UUID, foreign_key: :ppl_id)
    field(:after_task_id, :string)
    field(:state, :string)
    field(:result, :string)
    field(:result_reason, :string)
    field(:in_scheduling, :boolean)
    field(:error_description, :string)
    field(:recovery_count, :integer)
    field(:terminate_request, :string)
    field(:terminate_request_desc, :string)

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(ppl_id state in_scheduling)a
  @optional_fields ~w(result after_task_id result_reason error_description recovery_count
                      terminate_request terminate_request_desc)a

  @valid_states ~w(waiting pending running done)
  @valid_results ~w(passed failed stopped)

  @valid_failed_result_reasons ~w(test stuck)
  @valid_terminated_result_reasons ~w()
  @valid_terminate_requests ~w()

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:result, @valid_results)
    |> validate_result_reason_field()
    |> validate_terminate_request_field()
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_limit_per_ppl, name: :one_after_task_per_ppl)
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
