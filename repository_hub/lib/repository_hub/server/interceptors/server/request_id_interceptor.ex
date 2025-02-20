defmodule RepositoryHub.Server.RequestIdInterceptor do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(options) do
    options
  end

  def call(request, stream, next, _options) do
    request_id =
      stream
      |> GRPC.Stream.get_headers()
      |> then(fn headers ->
        headers
        |> Map.get_lazy("x-semaphore-request-id", fn ->
          [request_id | _] =
            Ecto.UUID.generate()
            |> String.split("-")
            |> Enum.reverse()

          request_id
        end)
      end)

    Logger.metadata(request_id: request_id)
    next.(request, stream)
  end
end
