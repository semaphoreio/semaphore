defmodule Zebra.Models.JobStopRequest do
  use Ecto.Schema

  import Ecto.Changeset

  require Ecto.Query
  require Logger

  alias Ecto.Query, as: Q

  def state_pending, do: "pending"
  def state_done, do: "done"
  def valid_states, do: [state_pending(), state_done()]

  def result_success, do: "success"
  def result_failure, do: "failure"
  def valid_results, do: [nil, result_success(), result_failure()]

  def result_reason_job_already_finished, do: "job_already_finished"
  def result_reason_job_transitioned_to_stopping, do: "job_transitioned_to_stopping"

  def valid_results_reasons,
    do: [
      result_reason_job_transitioned_to_stopping(),
      result_reason_job_already_finished()
    ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "job_stop_requests" do
    belongs_to(:task, Zebra.Models.Task, foreign_key: :build_id)
    belongs_to(:job, Zebra.Models.Job, foreign_key: :job_id)

    field(:state, :string)
    field(:result, :string)
    field(:result_reason, :string)
    field(:stopped_by, :string)

    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
    field(:done_at, :utc_datetime)
  end

  def pending(query \\ __MODULE__) do
    query |> Q.where([r], r.state == "pending")
  end

  def find_by_job_id(job_id) do
    stop_request =
      Zebra.Models.JobStopRequest
      |> Q.where([r], r.job_id == ^job_id)
      |> Zebra.LegacyRepo.one()

    if is_nil(stop_request) do
      {:error, :not_found}
    else
      {:ok, stop_request}
    end
  end

  def create(task_id, job_id, stopped_by \\ nil) do
    record = build_record(task_id, job_id, stopped_by)

    changeset(%__MODULE__{}, record) |> Zebra.LegacyRepo.insert()
  end

  @doc """
  Input: list of {task_id, job_id} tuples.

  A performant way to request a stop for multiple jobs/tasks.

  In case of duplicate entries, the error is ignored.

  Returns {:ok, inserted_records_count}
  """
  def bulk_create([]), do: {:ok, 0}

  def bulk_create(task_job_id_tuples, stopped_by \\ nil) do
    records =
      Enum.map(task_job_id_tuples, fn {task_id, job_id} ->
        build_record(task_id, job_id, stopped_by)
      end)

    {inserted_count, nil} =
      Zebra.LegacyRepo.insert_all(
        __MODULE__,
        records,
        on_conflict: :nothing
      )

    {:ok, inserted_count}
  end

  defp build_record(task_id, job_id, stopped_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    params = %{
      state: state_pending(),
      created_at: now,
      updated_at: now,
      job_id: job_id,
      build_id: task_id,
      stopped_by: stopped_by
    }

    params
  end

  def update(req, params \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    params = params |> Map.merge(%{updated_at: now})

    changeset(req, params) |> Zebra.LegacyRepo.update()
  end

  def complete(req, result, result_reason) do
    if req.state == state_pending() do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      update(req, %{
        state: state_done(),
        result: result,
        result_reason: result_reason,
        done_at: now
      })
    else
      {:error, :invalid_state_transition}
    end
  end

  def changeset(req, params \\ %{}) do
    req
    |> cast(params, [
      :build_id,
      :job_id,
      :state,
      :result,
      :result_reason,
      :stopped_by,
      :created_at,
      :updated_at,
      :done_at
    ])
    |> validate_inclusion(:state, valid_states())
    |> validate_inclusion(:result, valid_results())
    |> validate_inclusion(:result_reason, valid_results_reasons())
    |> unique_constraint(:job_id)
  end
end
