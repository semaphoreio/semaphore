defmodule GithubNotifier.Services.Api do
  require Logger

  use GRPC.Server, service: InternalApi.GithubNotifier.GithubNotifier.Service

  alias InternalApi.ResponseStatus

  alias InternalApi.GithubNotifier.{
    BlockStartedResponse,
    BlockFinishedResponse,
    PipelineStartedResponse,
    PipelineFinishedResponse
  }

  alias GithubNotifier.{Notifier, Utils}

  def block_started(req, _) do
    Watchman.benchmark("block_started.duration", fn ->
      request_id = Utils.RandomString.random_string(30)

      Notifier.notify(request_id, req.pipeline_id, req.block_id)

      BlockStartedResponse.new(status: status_ok())
    end)
  end

  def block_finished(req, _) do
    Watchman.benchmark("block_finished.duration", fn ->
      request_id = Utils.RandomString.random_string(30)

      Notifier.notify(request_id, req.pipeline_id, req.block_id)

      BlockFinishedResponse.new(status: status_ok())
    end)
  end

  def pipeline_started(req, _) do
    Watchman.benchmark("pipeline_started.duration", fn ->
      request_id = Utils.RandomString.random_string(30)

      Notifier.notify(request_id, req.pipeline_id)

      PipelineStartedResponse.new(status: status_ok())
    end)
  end

  def pipeline_finished(req, _) do
    Watchman.benchmark("pipeline_finished.duration", fn ->
      request_id = Utils.RandomString.random_string(30)

      Notifier.notify(request_id, req.pipeline_id)

      PipelineFinishedResponse.new(status: status_ok())
    end)
  end

  defp status_ok do
    ResponseStatus.new(code: ResponseStatus.Code.value(:OK))
  end
end
