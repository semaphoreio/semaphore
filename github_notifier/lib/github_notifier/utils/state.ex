defmodule GithubNotifier.Utils.State do
  @moduledoc false

  @success "success"
  @failure "failure"
  @stopped "stopped"
  @pending "pending"

  @message_build_passed "The build passed on Semaphore 2.0."
  @message_build_failed "The build failed on Semaphore 2.0."
  @message_build_canceled "The build was canceled on Semaphore 2.0."
  @message_build_pending "The build is pending on Semaphore 2.0."

  def extract(%{state: :DONE} = pipeline), do: verdict(pipeline.result)
  def extract(_pipeline), do: {@pending, @message_build_pending}

  def extract_with_summary(%{state: :DONE} = pipeline, pipeline_summary),
    do: verdict(pipeline.result, pipeline_summary)

  def extract_with_summary(_pipeline, _pipeline_summary),
    do: {@pending, @message_build_pending}

  defp verdict(:PASSED), do: {@success, @message_build_passed}

  # A stopped/canceled pipeline never reached a verdict, so it reports as
  # :STOPPED rather than a failure — an interrupted build is not a failed one.
  defp verdict(result) when result in [:STOPPED, :CANCELED],
    do: {@stopped, @message_build_canceled}

  defp verdict(_), do: {@failure, @message_build_failed}

  defp verdict(:PASSED, summary) do
    message =
      if summary.passed > 0,
        do: "#{pluralize(summary.passed, "test")} passed.",
        else: @message_build_passed

    {@success, message}
  end

  defp verdict(result, _summary) when result in [:STOPPED, :CANCELED],
    do: {@stopped, @message_build_canceled}

  defp verdict(_, summary) do
    failures = summary.failed + summary.error

    message =
      if failures > 0,
        do: "#{pluralize(failures, "test")} failed.",
        else: @message_build_failed

    {@failure, message}
  end

  defp pluralize(count, fragment) do
    count
    |> case do
      0 -> "none #{fragment}s"
      1 -> "1 #{fragment}"
      _ -> "#{count} #{fragment}s"
    end
  end
end
