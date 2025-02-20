defmodule PipelinesAPI.Loghub2Client do
  @moduledoc """
  Module is used for fetching logs for self-hosted jobs from loghub2
  """

  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias InternalApi.Loghub2.GenerateTokenRequest
  alias InternalApi.Loghub2.TokenType
  alias LogTee, as: LT

  defp url(), do: System.get_env("LOGHUB2_API_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])
  @token_duration 60 * 5

  def generate_token(job_id) do
    Metrics.benchmark(__MODULE__, ["generate_token"], fn ->
      form_generate_token_request(job_id)
      |> grpc_call()
    end)
  end

  def form_generate_token_request(job_id) do
    %{
      job_id: job_id,
      type: TokenType.value(:PULL),
      duration: @token_duration
    }
    |> GenerateTokenRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  defp grpc_call({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :do_generate_token, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        {:ok, result.token}

      {:error, reason} ->
        reason |> LT.error("loghub2 service responded with")
        ToTuple.internal_error("Internal error")
    end
  end

  defp grpc_call(error), do: error

  def do_generate_token(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()

    InternalApi.Loghub2.Loghub2.Stub.generate_token(channel, request, timeout: @wormhole_timeout)
  end
end
