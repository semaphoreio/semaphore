defmodule GithubNotifier.Utils.State do
  @moduledoc false

  @success "success"
  @failure "failure"
  @pending "pending"

  @message_build_passed "The build passed on Semaphore 2.0."
  @message_build_failed "The build failed on Semaphore 2.0."
  @message_build_pending "The build is pending on Semaphore 2.0."

  def extract(pipeline) do
    case pipeline.result do
      :PASSED ->
        case pipeline.state do
          :DONE -> {@success, @message_build_passed}
          _ -> {@pending, @message_build_pending}
        end

      _ ->
        case pipeline.state do
          :DONE -> {@failure, @message_build_failed}
          _ -> {@pending, @message_build_pending}
        end
    end
  end

  def extract_with_summary(pipeline, pipeline_summary) do
    case pipeline.result do
      :PASSED ->
        case pipeline.state do
          :DONE ->
            message =
              if pipeline_summary.passed > 0,
                do: "#{pluralize(pipeline_summary.passed, "test")} passed.",
                else: @message_build_passed

            {@success, message}

          _ ->
            {@pending, @message_build_pending}
        end

      _ ->
        case pipeline.state do
          :DONE ->
            failures = pipeline_summary.failed + pipeline_summary.error

            message =
              if failures > 0,
                do: "#{pluralize(failures, "test")} failed.",
                else: @message_build_failed

            {@failure, message}

          _ ->
            {@pending, @message_build_pending}
        end
    end
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
