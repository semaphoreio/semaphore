defmodule Front.Onboarding.ReadinessCheck do
  def waiting_message(_project),
    do: "<p>Hang in there!<br> Larger Git repositories need a bit more time to be analyzed.</p>"

  def waiting_message(_project, nil),
    do:
      "<p>Hang in there!<br> Forking repository is taking a little bit more time than usually.</p>"

  def waiting_message(_project, _workflow),
    do:
      "<p>Hang in there!<br> Starting a workflow is taking a little bit more time than usually.</p>"

  def error_message(nil), do: ""
  def error_message(:error), do: ""

  def error_message(project) do
    if project.state == :ERROR do
      project.state_reason
    else
      ""
    end
  end

  def should_make_ready?(nil), do: false
  def should_make_ready?(project), do: project.state == :ONBOARDING

  def ready(nil), do: false
  def ready(project), do: project.state == :ONBOARDING || project.state == :READY

  def ready(_, nil), do: false
  def ready(_, _), do: true

  def forking_ready(nil), do: false
  def forking_ready(:error), do: "error"
  def forking_ready(_), do: true

  def repository_ready(nil), do: false
  def repository_ready(:error), do: false
  def repository_ready(project), do: project.repository_state == :READY

  def artifacts_ready(nil), do: false
  def artifacts_ready(:error), do: false
  def artifacts_ready(project), do: project.artifact_store_state == :READY

  def cache_ready(nil), do: false
  def cache_ready(:error), do: false
  def cache_ready(project), do: project.cache_state == :READY

  def analysis_ready(nil), do: false
  def analysis_ready(:error), do: false
  def analysis_ready(project), do: project.analysis_state == :READY

  def permissions_ready(nil), do: false
  def permissions_ready(:error), do: "error"
  def permissions_ready(project), do: project.permissions_state == :READY

  def workflow_ready(nil), do: false
  def workflow_ready(:error), do: "error"
  def workflow_ready(_), do: true
end
