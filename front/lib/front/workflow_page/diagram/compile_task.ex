defmodule Front.WorkflowPage.Diagram.CompileTask do
  def assign(pipeline, tasks) do
    job = find_job(pipeline, tasks)

    if job do
      populate_compile_task(pipeline, job)
    else
      pipeline
    end
  end

  defp populate_compile_task(pipeline, job) do
    compile_task = populate_compile_task_fields(pipeline.compile_task, job)

    Map.put(pipeline, :compile_task, compile_task)
  end

  defp populate_compile_task_fields(compile_task, job) do
    compile_task
    |> Map.put(:job_id, job.id)
    |> Map.put(:job_log_path, "/jobs/#{job.id}")
    |> Map.put(:running?, job.state == :RUNNING)
    |> Map.put(:failed?, job.state == :FINISHED && job.result == :FAILED)
    |> Map.put(:done?, job.state == :FINISHED)
    |> Map.put(:started_at, started_at(job))
    |> Map.put(:done_at, finished_at(job))
  end

  defp started_at(job) do
    if job.started_at do
      job.started_at.seconds
    else
      nil
    end
  end

  defp finished_at(job) do
    if job.finished_at do
      job.finished_at.seconds
    else
      nil
    end
  end

  defp find_job(pipeline, tasks) do
    task = find_task(pipeline, tasks)

    if task && task.jobs != [] do
      hd(task.jobs)
    else
      nil
    end
  end

  defp find_task(pipeline, tasks) do
    if pipeline.compile_task.present? do
      tasks |> Enum.find(fn t -> t.id == pipeline.compile_task.task_id end)
    else
      nil
    end
  end
end
