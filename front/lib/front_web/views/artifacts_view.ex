defmodule FrontWeb.ArtifactsView do
  use FrontWeb, :view

  def artifact_kind(source_kind) do
    case source_kind do
      "projects" -> "project"
      "workflows" -> "workflow"
      "jobs" -> "job"
    end
  end
end
