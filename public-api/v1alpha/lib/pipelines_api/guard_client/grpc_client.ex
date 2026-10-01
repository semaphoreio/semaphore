defmodule PipelinesAPI.GuardClient.GrpcClient do
  @moduledoc false
  alias InternalApi.Guard.Guard, as: GuardService
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  require Logger

  defp url(), do: System.get_env("INTERNAL_API_URL_GUARD")

  @wormhole_timeout Application.compile_env(:pipelines_api, :wormhole_timeout, [])
  @grpc_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])
  defp opts(), do: [{:timeout, @grpc_timeout}]

  def invite_collaborators({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :invite_collaborators_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "invite_collaborators")
    end
  end

  def invite_collaborators(error), do: error

  def invite_collaborators_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.guard_client.grpc_client", ["invite_collaborators"], fn ->
      channel
      |> GuardService.Stub.invite_collaborators(request, opts())
      |> process_response("invite_collaborators")
    end)
  end

  defp process_response({:ok, response}, _action), do: response |> Util.Proto.to_map()

  defp process_response(
         {:error, %GRPC.RPCError{message: message, status: status}},
         action
       ) do
    cond do
      status in [3, 6, 9] -> ToTuple.user_error(message)
      status == 5 -> ToTuple.not_found_error(message)
      status == 7 -> ToTuple.forbidden_error(message)
      true -> Log.internal_error(message, action, "Guard")
    end
  end

  defp process_response({:error, error}, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "Guard")
  end

  defp process_response(error, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "Guard")
  end
end
