defmodule Front.Breadcrumbs.Artifacts do
  alias Front.Breadcrumbs

  def construct(assigns, conn, "jobs"),
    do: Breadcrumbs.Job.construct(assigns, conn, :artifacts)

  def construct(assigns, conn, "projects"),
    do: Breadcrumbs.Project.construct(assigns, conn, :artifacts)

  def construct(assigns, conn, "workflows"),
    do: Breadcrumbs.Workflow.construct(assigns, conn, "Artifacts")
end
