defmodule Projecthub.Util.GRPC.ClientRequestIdInterceptor do
  @behaviour GRPC.ClientInterceptor
  require Logger

  def init(request_id) do
    request_id
  end

  def call(stream, request, next, request_id) do
    request_id =
      request_id
      |> case do
        request_id when is_bitstring(request_id) and request_id != "" ->
          request_id

        _ ->
          Logger.metadata()
          |> Keyword.get(:request_id, Toolkit.generate_request_id())
      end

    headers =
      stream.headers
      |> Map.put("x-semaphore-request-id", request_id)

    stream =
      stream
      |> GRPC.Client.Stream.put_headers(headers)

    Logger.metadata(request_id: request_id)
    next.(stream, request)
  end
end
