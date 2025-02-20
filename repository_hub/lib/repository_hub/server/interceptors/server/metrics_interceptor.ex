defmodule RepositoryHub.Server.MetricsInterceptor do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(options) do
    options
  end

  def call(request, stream, next, _) do
    action_name =
      request.__struct__
      |> Atom.to_string()
      |> String.trim("Request")
      |> String.split(".")
      |> List.last()

    try do
      Watchman.benchmark("RepositoryHub.#{action_name}", fn ->
        next.(request, stream)
      end)
      |> tap(fn _ ->
        Watchman.increment({"RepositoryHub.#{action_name}", [GRPC.Status.code_name(GRPC.Status.ok())]})
      end)
    rescue
      e in GRPC.RPCError ->
        Watchman.increment({"RepositoryHub.#{action_name}", [GRPC.Status.code_name(e.status)]})

        reraise(e, __STACKTRACE__)
    end
  end
end
