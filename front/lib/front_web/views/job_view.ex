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

  def format_duration(nil, _), do: nil
  def format_duration(_, nil), do: nil
  def format_duration(from, to) when to > from, do: Front.DurationFormatter.format(to - from)
  def format_duration(_, _), do: nil

  def queue_time(%{created_at: nil}), do: nil
  def queue_time(%{created_at: _, started_at: nil}), do: nil

  def queue_time(%{created_at: created, started_at: started}),
    do: format_duration(created, started)

  def execution_time(%{started_at: nil}), do: nil
  def execution_time(%{started_at: _, finished_at: nil}), do: nil

  def execution_time(%{started_at: started, finished_at: finished}),
    do: format_duration(started, finished)

  def job_state_label("pending"), do: "Pending"
  def job_state_label("running"), do: "Running"
  def job_state_label("passed"), do: "Passed"
  def job_state_label("failed"), do: "Failed"
  def job_state_label("stopped"), do: "Stopped"
  def job_state_label(_), do: "Unknown"

  def job_state_badge_class("pending"), do: "bg-washed-yellow dark-yellow"
  def job_state_badge_class("running"), do: "bg-washed-blue dark-blue"
  def job_state_badge_class("passed"), do: "bg-washed-green dark-green"
  def job_state_badge_class("failed"), do: "bg-washed-red dark-red"
  def job_state_badge_class("stopped"), do: "bg-light-gray dark-gray"
  def job_state_badge_class(_), do: "bg-light-gray dark-gray"

  def stop_reason_label(block_result_reason) do
    case block_result_reason do
      :TIMEOUT -> "Execution time limit exceeded"
      :STUCK -> "Job was stuck and automatically stopped"
      :FAST_FAILING -> "Stopped due to fail-fast policy"
      :STRATEGY -> "Stopped by pipeline strategy"
      :USER -> "Manually stopped by user"
      :DELETED -> "Stopped because pipeline was deleted"
      :INTERNAL -> "Stopped due to internal error"
      _ -> "Stopped"
    end
  end

  def stop_reason_short(block_result_reason) do
    case block_result_reason do
      :TIMEOUT -> "Timed out"
      :STUCK -> "Stuck"
      :FAST_FAILING -> "Fail-fast"
      :STRATEGY -> "Strategy"
      :USER -> "User stopped"
      :DELETED -> "Deleted"
      :INTERNAL -> "Internal error"
      _ -> "Stopped"
    end
  end

  defp job_state_color("pending"), do: "bg-orange"
  defp job_state_color("running"), do: "bg-indigo"
  defp job_state_color("passed"), do: "bg-green"
  defp job_state_color("failed"), do: "bg-red"
  defp job_state_color("stopped"), do: "bg-gray"
end
