defmodule Projecthub.GrpcClient do
  defmacro __using__(opts \\ []) do
    service =
      Keyword.fetch(opts, :service)
      |> case do
        {:ok, service} -> service
        :error -> raise ":service is missing"
      end

    endpoint =
      Keyword.fetch(opts, :endpoint)
      |> case do
        {:ok, endpoint} -> endpoint
        :error -> raise ":endpoint is missing"
      end

    interceptors = Keyword.get(opts, :interceptors, [])

    quote do
      def grpc_call(request, action, grpc_opts \\ []) do
        unquote(endpoint)
        |> GRPC.Stub.connect(interceptors: unquote(interceptors))
        |> then(fn
          {:ok, channel} ->
            apply(unquote(service).Stub, action, [channel, request, with_default_opts(grpc_opts)])

          error ->
            error
        end)
      end

      defp decorate(request, schema) when is_struct(request, schema), do: request

      defp decorate(request, schema), do: schema.new(request)

      defp with_default_opts(current_opts) do
        [
          timeout: :timer.seconds(10),
          metadata: nil
        ]
        |> Keyword.merge(current_opts)
      end

      defoverridable with_default_opts: 1
    end
  end
end
