defmodule Block.ListenerProxyClient do
  @moduledoc """
  Fetches configuration blobs from listener proxy
  """
  require Logger

  @timeout :timer.seconds(2)

  alias InternalApi.Stethoscope.{GetBlobRequest, StethoscopeService}

  def get_cfg(key, wf_id) do
    request =
      GetBlobRequest.new(
        wf_id: wf_id,
        uri: "cfg://" <> key
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:22345")

    Logger.info("Fetching config with request: #{inspect(request)}")
    response = StethoscopeService.Stub.get_blob(channel, request, timeout: @timeout)

    Logger.info("Config response: #{inspect(response)}")
    response
  end
end
