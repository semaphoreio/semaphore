defmodule RepositoryHub.Client.MetricsInterceptor do
  @behaviour GRPC.ClientInterceptor
  require Logger

  def init(options) do
    options
  end

  def call(stream, request, next, _) do
    call_path =
      request.__struct__
      |> Atom.to_string()
      |> String.trim("Request")
      |> String.trim("Elixir.InternalApi.")
      |> String.split(".")

    action_name = List.last(call_path)

    service_name = List.first(call_path)

    try do
      next.(stream, request)
      |> tap(fn _ ->
        Watchman.increment({"RepositoryHub.#{service_name}.#{action_name}", [GRPC.Status.code_name(GRPC.Status.ok())]})
      end)
    rescue
      e in GRPC.RPCError ->
        Watchman.increment({"RepositoryHub.#{service_name}.#{action_name}", [GRPC.Status.code_name(e.status)]})

        reraise(e, __STACKTRACE__)
    end
  end
end
