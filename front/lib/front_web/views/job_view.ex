defmodule FrontWeb.JobView do
  use FrontWeb, :view

  def failed_to_start?(job) do
    job.timeline.started_at == nil && job.failure_reason != ""
  end

  def debug_or_attach_cmd("debug", job_id), do: "sem debug job #{job_id}"
  def debug_or_attach_cmd("attach", job_id), do: "sem attach #{job_id}"

  def debug_or_attach_txt("debug"),
    do: "Debugging is disabled for this job. Enable it in"

  def debug_or_attach_txt("attach"),
    do: "Attaching is disabled for this job. Enable it in"

  def debug_or_attach_self_hosted_txt("debug"),
    do: "Debugging is not available for self-hosted jobs."

  def debug_or_attach_self_hosted_txt("attach"),
    do: "Attaching is not available for self-hosted jobs."

  def logs_url(conn, job, _org) do
    if job.self_hosted do
      "/api/v1/logs/#{job.id}"
    else
      job_path(conn, :logs, job.id)
    end
  end

  def job_timer(job), do: job_timer(job.state, job.timeline)

  def job_timer("pending", timeline) do
    "<span class='f5 code'>#{FrontWeb.SharedView.total_time(timeline.started_at, timeline.finished_at)}</span>"
  end

  def job_timer("running", timeline) do
    "<span class='f5 code' timer run seconds=#{FrontWeb.SharedView.total_seconds(timeline.started_at, timeline.finished_at)}>#{FrontWeb.SharedView.total_time(timeline.started_at, timeline.finished_at)}</span>"
  end

  def job_timer("passed", timeline) do
    "<span class='f5 code'>#{FrontWeb.SharedView.total_time(timeline.started_at, timeline.finished_at)}</span>"
  end

  def job_timer("failed", %{started_at: nil}) do
    "<span class='f5 code'>--:--</span>"
  end

  def job_timer("failed", timeline) do
    "<span class='f5 code'>#{FrontWeb.SharedView.total_time(timeline.started_at, timeline.finished_at)}</span>"
  end

  def job_timer("stopped", timeline) do
    "<span class='f5 code'>#{FrontWeb.SharedView.total_time(timeline.started_at, timeline.finished_at)}</span>"
  end

  def job_pending_message(job) do
    if job.self_hosted do
      "No self-hosted agent is available to run this job yet.
      If this state persists for too long, contact the person responsible for managing agents for the #{job.machine_type} self-hosted agent type."
    else
      "The job is waiting on #{job.machine_type} quota."
    end
  end

  defp job_state_color("pending"), do: "bg-orange"
  defp job_state_color("running"), do: "bg-indigo"
  defp job_state_color("passed"), do: "bg-green"
  defp job_state_color("failed"), do: "bg-red"
  defp job_state_color("stopped"), do: "bg-gray"

  def stopped_by_message(assigns) do
    job = assigns.job
    stopped_by_user = assigns.stopped_by_user

    cond do
      job.state != "stopped" -> ""
      is_nil(job.stopped_by) -> "Job was stopped"
      String.starts_with?(job.stopped_by, "system:") -> "Job was stopped by the system"
      is_nil(stopped_by_user) -> "Job was stopped by user #{job.stopped_by}"
      true -> "Job was stopped by #{stopped_by_user.name}"
    end
  end
end
