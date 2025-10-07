defmodule Front.Breadcrumbs.Job do
  def construct(assigns, conn, :artifacts) do
    breadcrumbs = [
      %{
        type: :project,
        name: conn.assigns.project.name,
        url: "/projects/#{conn.assigns.project.name}",
        last: false
      },
      %{
        type: :branch,
        name: assigns.hook.name,
        url: "/branches/#{assigns.workflow.branch_id}",
        last: false
      },
      %{
        type: :workflow,
        name: assigns.workflow_name,
        url: "/workflows/#{assigns.workflow.id}?pipeline_id=#{assigns.workflow.root_pipeline_id}",
        last: false
      },
      %{name: "Artifacts", last: true}
    ]

    Map.put(assigns, :breadcrumbs, breadcrumbs)
  end

  def construct(assigns, _conn, :test_results) do
    breadcrumbs = [
      %{
        type: :project,
        name: assigns.project.name,
        url: "/projects/#{assigns.project.name}",
        last: false
      },
      %{
        type: :branch,
        name: assigns.hook.name,
        url: "/branches/#{assigns.workflow.branch_id}",
        last: false
      },
      %{
        type: :workflow,
        name: assigns.workflow_name,
        url: "/workflows/#{assigns.workflow.id}?pipeline_id=#{assigns.workflow.root_pipeline_id}",
        last: false
      },
      %{name: "Tests", last: true}
    ]

    Map.put(assigns, :breadcrumbs, breadcrumbs)
  end

  def construct(assigns, _conn, :reports) do
    breadcrumbs = [
      %{
        type: :project,
        name: assigns.project.name,
        url: "/projects/#{assigns.project.name}",
        last: false
      },
      %{
        type: :branch,
        name: assigns.hook.name,
        url: "/branches/#{assigns.workflow.branch_id}",
        last: false
      },
      %{
        type: :workflow,
        name: assigns.workflow_name,
        url: "/workflows/#{assigns.workflow.id}?pipeline_id=#{assigns.workflow.root_pipeline_id}",
        last: false
      },
      %{name: "Reports", last: true}
    ]

    Map.put(assigns, :breadcrumbs, breadcrumbs)
  end

  def construct(assigns, conn, title) do
    breadcrumbs = [
      %{
        type: :project,
        name: conn.assigns.project.name,
        url: "/projects/#{conn.assigns.project.name}",
        last: false
      },
      %{
        type: :branch,
        name: assigns.hook.name,
        url: "/branches/#{assigns.workflow.branch_id}",
        last: false
      },
      %{
        type: :workflow,
        name: assigns.workflow_name,
        url: "/workflows/#{assigns.workflow.id}?pipeline_id=#{assigns.workflow.root_pipeline_id}",
        last: false
      },
      %{name: title, last: true}
    ]

    Map.put(assigns, :breadcrumbs, breadcrumbs)
  end
end
