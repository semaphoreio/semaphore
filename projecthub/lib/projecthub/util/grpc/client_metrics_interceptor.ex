defmodule Projecthub.Util.GRPC.ClientMetricsInterceptor do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(namespace) do
    namespace
  end

  def call(stream, request, next, namespace) do
    action_name =
      request.__struct__
      |> Atom.to_string()
      |> String.trim("Request")
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()

    try do
      Watchman.benchmark("#{namespace}.#{action_name}.duration", fn ->
        next.(stream, request)
      end)
      |> tap(fn
        {:ok, _} -> Watchman.increment("#{namespace}.#{action_name}.success")
        {:error, _} -> Watchman.increment("#{namespace}.#{action_name}.failure")
      end)
    rescue
      e in GRPC.RPCError ->
        Watchman.increment("#{namespace}.#{action_name}.failure")

        reraise(e, __STACKTRACE__)
    end
  end
end
