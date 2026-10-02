defmodule GithubNotifier.NotifierTest do
  use ExUnit.Case

  alias GithubNotifier.Notifier

  # Regression tests for the "build passed but no status posted to GitHub"
  # failure: a dependency `describe` that is slower than the fetch timeout used
  # to return `nil` from `Task.yield/1` and crash with `{:badmatch, nil}`,
  # skipping `Status.create`. It must now raise a retryable error instead, so
  # the Tackle consumer redelivers rather than silently dropping the status.
  #
  # `:fetch_timeout` is set to 200ms in config/test.exs; the slow stubs sleep
  # well past that to trip the timeout deterministically.

  describe "notify/3 when a dependency fetch exceeds the fetch timeout" do
    test "retries (raises) instead of crashing with {:badmatch, nil} when the pipeline describe is slow" do
      GrpcMock.stub(PipelineMock, :describe, fn _req, _stream ->
        Process.sleep(800)
        Support.Factories.pipeline_describe_response()
      end)

      assert_raise RuntimeError, ~r/pipeline fetch unavailable/, fn ->
        Notifier.notify("req-id", "pipeline-id")
      end
    end

    test "raises when a later fetch (repo_proxy) is slow even though the pipeline resolved" do
      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      GrpcMock.stub(RepoProxyMock, :describe, fn _req, _stream ->
        Process.sleep(800)
        Support.Factories.repo_proxy_describe_response()
      end)

      assert_raise RuntimeError, ~r/repo_proxy fetch unavailable/, fn ->
        Notifier.notify("req-id", "pipeline-id")
      end
    end
  end
end
