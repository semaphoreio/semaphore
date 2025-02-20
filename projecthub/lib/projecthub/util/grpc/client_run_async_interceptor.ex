defmodule Projecthub.Util.GRPC.ClientRunAsyncInterceptor do
  @behaviour GRPC.ClientInterceptor
  require Logger

  @type opts :: [
          timeout: non_neg_integer()
        ]

  @spec init(opts()) :: opts()
  def init(opts) do
    opts
  end

  def call(stream, request, next, opts) do
    metadata = Logger.metadata()
    timeout = Keyword.get(opts, :timeout, :timer.seconds(30))

    Task.async(fn ->
      Logger.metadata(metadata)
      next.(stream, request)
    end)
    |> Task.await(timeout)
  end
end
