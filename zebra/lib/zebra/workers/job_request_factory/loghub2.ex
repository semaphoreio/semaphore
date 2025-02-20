defmodule Zebra.Workers.JobRequestFactory.Loghub2 do
  require Logger

  def generate_token(job_id) do
    Watchman.benchmark("zebra.external.loghub2.generate-token", fn ->
      alias InternalApi.Loghub2.GenerateTokenRequest, as: Request
      alias InternalApi.Loghub2.TokenType
      alias InternalApi.Loghub2.Loghub2.Stub

      req = Request.new(job_id: job_id, type: TokenType.value(:PUSH))

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :loghub2_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, res} <- Stub.generate_token(channel, req, timeout: 30_000) do
        {:ok, res.token}
      else
        e ->
          Logger.info("Failed to generate loghub2 PUSH token for Job##{job_id}, #{inspect(e)}")

          {:error, :communication_error}
      end
    end)
  end
end
