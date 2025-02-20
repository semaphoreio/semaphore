defmodule Front.Clients.Scouter do
  require Logger

  alias InternalApi.Scouter.{
    Context,
    ListEventsRequest,
    # ListEventsResponse,
    SignalRequest
    # SignalResponse
  }

  alias Front

  @behaviour Front.Scouter.Behaviour

  @impl Front.Scouter.Behaviour
  def list(
        context,
        event_ids
      ) do
    %ListEventsRequest{
      context: build_context(context),
      event_ids: event_ids
    }
    |> grpc_call(:list_events)
    |> case do
      {:ok, result} ->
        {:ok, result.events}

      err ->
        Logger.error(
          "Error listing events #{inspect(event_ids)} for #{inspect(context)}: #{inspect(err)}"
        )

        {:error, "failed to fetch events"}
    end
  end

  @impl Front.Scouter.Behaviour
  def signal(
        context,
        event_id
      ) do
    %SignalRequest{
      context: build_context(context),
      event_id: event_id
    }
    |> grpc_call(:signal)
    |> case do
      {:ok, result} ->
        {:ok, result.event}

      err ->
        Logger.error(
          "Error signaling event #{inspect(event_id)} for #{inspect(context)}: #{inspect(err)}"
        )

        {:error, "failed to signal an event"}
    end
  end

  defp build_context(context) do
    %Context{
      organization_id: Kernel.get_in(context, [:organization_id]) || "",
      user_id: Kernel.get_in(context, [:user_id]) || "",
      project_id: Kernel.get_in(context, [:project_id]) || ""
    }
  end

  defp grpc_call(request, action) do
    Watchman.benchmark("scouter.#{action}.duration", fn ->
      channel()
      |> call_grpc(
        InternalApi.Scouter.ScouterService.Stub,
        action,
        request,
        metadata(),
        timeout()
      )
      |> tap(fn
        {:ok, _} -> Watchman.increment("scouter.#{action}.success")
        {:error, _} -> Watchman.increment("scouter.#{action}.failure")
      end)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to Scouter: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:front, :scouter_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp timeout do
    2_000
  end

  defp metadata do
    nil
  end
end
