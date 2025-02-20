defmodule Projecthub.Util.GRPC.ServerMetricsInterceptor do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(namespace) do
    namespace
  end

  def call(request, stream, next, namespace) do
    action_name =
      request.__struct__
      |> Atom.to_string()
      |> String.trim("Request")
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()

    try do
      Watchman.benchmark("#{namespace}.#{action_name}", fn ->
        next.(request, stream)
      end)
      |> tap(fn _ ->
        Watchman.increment({"#{namespace}.#{action_name}", [GRPC.Status.code_name(GRPC.Status.ok())]})
      end)
    rescue
      e in GRPC.RPCError ->
        Watchman.increment({"#{namespace}.#{action_name}", [GRPC.Status.code_name(e.status)]})

        reraise(e, __STACKTRACE__)
    end
  end
end
