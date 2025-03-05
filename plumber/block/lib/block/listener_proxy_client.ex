defmodule Block.ListenerProxyClient do
  @moduledoc """
  Fetches configuration blobs from listener proxy
  """

  @timeout :timer.seconds(2)

  alias InternalApi.Stethoscope.{GetBlobRequest, StethoscopeService}

  def get_cfg(key, wf_id) do
    request =
      GetBlobRequest.new(
        wf_id: wf_id,
        uri: "cfg://" <> key
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:22345")

    StethoscopeService.Stub.get_blob(channel, request, timeout: @timeout)
  end
end
