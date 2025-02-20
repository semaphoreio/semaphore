defmodule Ppl.UserClient do
  @moduledoc """
  Calls User internal API
  """

  alias LogTee, as: LT
  alias Util.{Metrics, Proto, ToTuple}
  alias InternalApi.User.{UserService, DescribeRequest}

  defp url(), do: System.get_env("INTERNAL_API_URL_USER")
  @opts [{:timeout, 2_500_000}]

  @doc """
  Entrypoint for describe user call from ppl application.
  """
  def describe(user_id) do
    result =  Wormhole.capture(__MODULE__, :describe_user, [user_id], stacktrace: true, timeout: 3_000)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_user(user_id) do
    Metrics.benchmark("Ppl.UserClient.describe", fn ->
      request = DescribeRequest.new(user_id: user_id)
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> UserService.Stub.describe(request, @opts)
      |> response_to_map()
      |> process_status()
    end)
  end

  defp process_status({:ok, map}) do
    case map |> Map.get(:status, %{}) |> Map.get(:code) do
      :OK ->
         map |> ToTuple.ok()

      :BAD_PARAM ->
         map |> Map.get(:status, %{}) |> Map.get(:message) |> ToTuple.error()

      _ -> log_invalid_response(map)
    end
  end
  defp process_status(error = {:error, _msg}), do: error
  defp process_status(error), do: {:error, error}

  # Utility

  defp response_to_map({:ok, response}), do: Proto.to_map(response)
  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: {:error, error}

  defp log_invalid_response(response) do
    response
    |> LT.error("User Service responded to Describe with :ok and invalid data:")
    |> ToTuple.error()
  end
end
