defmodule Front.Breadcrumbs.Workflow do
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
        url: "/branches/#{conn.assigns.workflow.branch_id}",
        last: false
      },
      %{name: title, last: true}
    ]

    Map.put(assigns, :breadcrumbs, breadcrumbs)
  end
end
