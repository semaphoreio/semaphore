defmodule Support.Factories.Debug do
  alias Zebra.Models.Debug

  @id Ecto.UUID.generate()
  @job_id Ecto.UUID.generate()

  def id, do: @id
  def job_id, do: @job_id

  def create do
    {:ok, origin_job} = Support.Factories.Job.create(:started)
    {:ok, session_job} = Support.Factories.Job.create(:started)

    {:ok, debug} = create_for_job(session_job.id, origin_job.id)

    {:ok, debug}
  end

  def create_for_job(debugged_id \\ nil, job_id \\ nil, user_id \\ nil) do
    debugged_id = debugged_id || @id
    job_id = job_id || @job_id
    user_id = user_id || Ecto.UUID.generate()

    Debug.create(job_id, Debug.type_job(), debugged_id, user_id)
  end
end
