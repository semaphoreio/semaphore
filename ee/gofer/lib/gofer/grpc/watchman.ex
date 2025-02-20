defmodule Gofer.Grpc.Watchman do
  @moduledoc """
  gRPC interceptor sending metrics to via Watchamn to InfluxDB
  """

  @behaviour GRPC.ServerInterceptor
  @default_prefix "grpc"

  @impl true
  def init(opts) do
    prefix = Keyword.get(opts, :prefix, @default_prefix)
    [prefix: prefix]
  end

  @impl true
  def call(request, stream, next, opts) do
    metric = "#{opts[:prefix]}.#{req_to_metric(request)}"

    result =
      Watchman.benchmark(metric, fn ->
        run_next(next, request, stream)
      end)

    Watchman.submit({metric, [status_code(result)]}, 1)

    case result do
      {:ok, response} ->
        response

      {:error, {error = %GRPC.RPCError{}, stacktrace}} ->
        reraise error, stacktrace
    end
  end

  defp status_code({:ok, _response}), do: "OK"

  defp status_code({:error, {%GRPC.RPCError{status: status}, _st}}),
    do: GRPC.Status.code_name(status)

  defp status_code({:error, _reason}), do: "Unknown"

  defp run_next(next, request, stream) do
    {:ok, next.(request, stream)}
  rescue
    error in GRPC.RPCError ->
      {:error, {error, __STACKTRACE__}}
  end

  defp req_to_metric(%{__struct__: struct}) do
    struct
    |> Module.split()
    |> List.last()
    |> String.trim_trailing("Request")
    |> String.downcase()
  end
end
