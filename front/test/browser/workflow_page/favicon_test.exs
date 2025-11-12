defmodule Front.Browser.WorkflowPage.FaviconTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowPage, as: Page

  @pipeline_status_interval 500
  @pipeline_status_response_limit 100

  setup data do
    stubs = Support.Browser.WorkflowPage.create_workflow()

    Support.Stubs.PermissionPatrol.allow_everything()

    context = Map.merge(data, stubs)

    {:ok, context}
  end

  browser_test "when pipeline is running favicon is in running state", params do
    Support.Stubs.Pipeline.change_state(params.pipeline.id, :running)
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-running.png"
    assert Page.current_favicon(page) == "/images/favicon-running.svg"
  end

  browser_test "when pipeline is running favicon is in passed state", params do
    Support.Stubs.Pipeline.change_state(params.pipeline.id, :passed)
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-passed.png"
    assert Page.current_favicon(page) == "/images/favicon-passed.svg"
  end

  browser_test "when pipeline is running favicon is in failed state", params do
    Support.Stubs.Pipeline.change_state(params.pipeline.id, :failed)
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-failed.png"
    assert Page.current_favicon(page) == "/images/favicon-failed.svg"
  end

  browser_test "when pipeline is running favicon is in stopping state", params do
    Support.Stubs.Pipeline.change_state(params.pipeline.id, :stopping)
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-stopped.png"
    assert Page.current_favicon(page) == "/images/favicon-stopped.svg"
  end

  browser_test "when pipeline is running favicon is in stopped state", params do
    Support.Stubs.Pipeline.change_state(params.pipeline.id, :stopped)
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-stopped.png"
    assert Page.current_favicon(page) == "/images/favicon-stopped.svg"
  end

  browser_test "when pipeline is running favicon is in pending state", params do
    Support.Stubs.Pipeline.change_state(params.pipeline.id, :pending)
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-queued.png"
    assert Page.current_favicon(page) == "/images/favicon-queued.svg"
  end

  browser_test "when pipeline is running favicon is in canceled state", params do
    Support.Stubs.Pipeline.change_state(params.pipeline.id, :canceled)
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-not-completed.png"
    assert Page.current_favicon(page) == "/images/favicon-not-completed.svg"
  end

  browser_test "pipeline state change", params do
    page = open(params)

    Process.sleep(@pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-queued.png"
    assert Page.current_favicon(page) == "/images/favicon-queued.svg"

    Support.Stubs.Pipeline.change_state(params.pipeline.id, :running)

    page =
      open(params)
      |> execute_script("window.FaviconUpdater.setInterval(#{@pipeline_status_interval});")

    Process.sleep(@pipeline_status_interval + @pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-running.png"
    assert Page.current_favicon(page) == "/images/favicon-running.svg"

    Support.Stubs.Pipeline.change_state(params.pipeline.id, :passed)

    page =
      open(params)
      |> execute_script("window.FaviconUpdater.setInterval(#{@pipeline_status_interval});")

    Process.sleep(@pipeline_status_interval + @pipeline_status_response_limit)

    assert Page.current_alternative_favicon(page) == "/images/favicon-passed.png"
    assert Page.current_favicon(page) == "/images/favicon-passed.svg"
  end

  defp open(params) do
    path = "/workflows/#{params.workflow.id}?pipeline_id=#{params.pipeline.id}"

    params.session |> visit(path)
  end
end
