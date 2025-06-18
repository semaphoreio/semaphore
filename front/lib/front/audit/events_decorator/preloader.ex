defmodule Front.Audit.EventsDecorator.Preloader do
  @moduledoc """
  Utility module for injecting related entities into every event that have a project,
  branch, workflow, or pipeline id in the metadata information. Later, on the Audit List
  UI page, these entities will be linked.
  """

  alias Front.Models.Workflow

  @type event_list :: [String.t()]
  @type id_list :: [String.t()]

  @type project_list :: [Project.t()]
  @type workflow_list :: [Workflow.t()]
  @type pipeline_id :: [Pipeline.t()]

  @spec preload(event_list()) :: event_list()
  def preload(events) do
    project_ids = extract_unique_id_list(events, :project_id)
    workflow_ids = extract_unique_id_list(events, :workflow_id)
    pipeline_ids = extract_unique_id_list(events, :pipeline_id)
    job_ids = extract_unique_id_list(events, :job_id)

    projects = Front.Models.Project.find_many_by_ids(project_ids)
    workflows = Front.Models.Workflow.find_many_by_ids(workflow_ids)
    pipelines = Front.Models.Pipeline.find_many(pipeline_ids)
    jobs = find_jobs_by_ids(job_ids)

    inject(events, %{
      projects: remove_nils(projects),
      workflows: remove_nils(workflows),
      pipelines: remove_nils(pipelines),
      jobs: remove_nils(jobs)
    })
  end

  defp inject(events, data) do
    Enum.map(events, fn event ->
      project = Enum.find(data.projects, fn p -> p.id == event.project_id end)
      workflow = Enum.find(data.workflows, fn w -> w.id == event.workflow_id end)
      pipeline = Enum.find(data.pipelines, fn p -> p.id == event.pipeline_id end)
      job = Enum.find(data.jobs, fn j -> j.id == event.job_id end)

      event
      |> add_if_not_nil(project, :project, :has_project)
      |> add_if_not_nil(workflow, :workflow, :has_workflow)
      |> add_if_not_nil(pipeline, :pipeline, :has_pipeline)
      |> add_if_not_nil(job, :job, :has_job)
    end)
  end

  defp add_if_not_nil(event, nil, _field, _existance_field), do: event

  defp add_if_not_nil(event, item, field, existance_field) do
    event |> Map.put(field, item) |> Map.put(existance_field, true)
  end

  defp extract_unique_id_list(events, id_name) do
    events
    |> Enum.filter(fn e -> Map.get(e, id_name) != nil end)
    |> Enum.map(fn e -> Map.get(e, id_name) end)
    |> Enum.uniq()
  end

  defp remove_nils(arr), do: Enum.filter(arr, fn e -> e != nil end)

  defp find_jobs_by_ids([]), do: []

  defp find_jobs_by_ids([id | ids]) do
    Front.Models.Job.find(id)
    |> case do
      nil -> find_jobs_by_ids(ids)
      job -> [job | find_jobs_by_ids(ids)]
    end
  end
end
