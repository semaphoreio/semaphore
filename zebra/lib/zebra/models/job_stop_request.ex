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

  def create(task_id, job_id) do
    record = build_record(task_id, job_id)

    changeset(%__MODULE__{}, record) |> Zebra.LegacyRepo.insert()
  end

  # Each row binds 6 parameters (id, build_id, job_id, state, created_at,
  # updated_at) and Postgres caps a statement at 65,535 parameters, so a single
  # insert_all fails above 10,922 rows. Insert in chunks well below that.
  @bulk_create_chunk_size 5_000

  def bulk_create_chunk_size, do: @bulk_create_chunk_size

  @doc """
  Input: list of {task_id, job_id} tuples.

  A performant way to request a stop for multiple jobs/tasks.

  In case of duplicate entries, the error is ignored.

  Any number of tuples is accepted: they are inserted in chunks inside one
  transaction, so either all of them are inserted or none are.

  Returns {:ok, inserted_records_count}
  """
  def bulk_create([]), do: {:ok, 0}

  def bulk_create(task_job_id_tuples) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Zebra.LegacyRepo.transaction(fn ->
      task_job_id_tuples
      |> Stream.map(fn {task_id, job_id} -> build_record(task_id, job_id, now) end)
      |> Stream.chunk_every(@bulk_create_chunk_size)
      |> Enum.reduce(0, fn records, total ->
        {inserted_count, nil} =
          Zebra.LegacyRepo.insert_all(__MODULE__, records, on_conflict: :nothing)

        total + inserted_count
      end)
    end)
  end

  defp build_record(task_id, job_id) do
    build_record(task_id, job_id, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp build_record(task_id, job_id, now) do
    %{
      state: state_pending(),
      created_at: now,
      updated_at: now,
      job_id: job_id,
      build_id: task_id
    }
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
