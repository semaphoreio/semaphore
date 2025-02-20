defmodule Support.Factories.Task do
  @hook_id Ecto.UUID.generate()

  def hook_id, do: @hook_id

  def create(params \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Zebra.Models.Task.create(
      Map.merge(
        %{
          created_at: now,
          build_request_id: Ecto.UUID.generate(),
          hook_id: @hook_id,
          workflow_id: Ecto.UUID.generate(),
          ppl_id: Ecto.UUID.generate(),
          branch_id: Ecto.UUID.generate()
        },
        params
      )
    )
  end

  def create_with_jobs(job_count \\ 2, result \\ nil) do
    {:ok, task} = create(%{result: result})

    0..(job_count - 1)
    |> Enum.each(fn _ ->
      Support.Factories.Job.create(:started, %{build_id: task.id})
    end)

    {:ok, task}
  end

  def create_jobs_valid_timestamps(params \\ %{}, job_params \\ %{}, job_count \\ 1) do
    {:ok, task} = create(params)

    0..(job_count - 1)
    |> Enum.each(fn _ ->
      job_params =
        %{build_id: task.id, created_at: DateTime.utc_now()}
        |> Map.merge(job_params)

      Support.Factories.Job.create(:started, job_params)
    end)

    {:ok, task}
  end
end
