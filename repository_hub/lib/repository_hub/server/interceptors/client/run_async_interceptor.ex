defmodule RepositoryHub.Client.RunAsyncInterceptor do
  @behaviour GRPC.ClientInterceptor
  require Logger

  def init(opts) do
    opts
  end

  def call(stream, request, next, _) do
    metadata = Logger.metadata()

    Task.async(fn ->
      Logger.metadata(metadata)
      next.(stream, request)
    end)
    |> Task.await(:timer.seconds(30))
  end
end
