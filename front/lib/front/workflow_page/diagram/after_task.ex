defmodule Front.WorkflowPage.Diagram.AfterTask do
  def assign(pipeline, topology, tasks) do
    task =
      if pipeline.after_task.present? do
        tasks |> Enum.find(fn t -> t.id == pipeline.after_task.task_id end)
      end

    fetch_jobs(topology)
    |> Enum.map(&build_job(&1, task))
    |> then(&populate_after_task(pipeline, &1))
  end

  defp populate_after_task(pipeline, jobs) do
    after_task = Map.put(pipeline.after_task, :jobs, jobs)

    Map.put(pipeline, :after_task, after_task)
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

  defp build_job(job, _task = nil) do
    %{
      id: job.id,
      name: job.name,
      running?: job.state == :RUNNING,
      failed?: job.state == :FINISHED && job.result == :FAILED,
      stopped?: job.state == :FINISHED && job.result == :STOPPED,
      passed?: job.state == :FINISHED && job.result == :PASSED,
      done?: job.state == :FINISHED,
      started_at: started_at(job),
      done_at: finished_at(job)
    }
  end

  defp build_job(job, task) do
    job = Enum.find(task.jobs, job, &(&1.name == job.name))
    build_job(job, nil)
  end

  defp fetch_jobs(topology) do
    topology.after_task.jobs
  end
end
