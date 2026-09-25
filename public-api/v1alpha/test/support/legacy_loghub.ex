defmodule Support.LegacyLoghub do
  @moduledoc """
  A loghub that predates StreamLogEvents: its service only has GetLogEvents,
  so a StreamLogEvents call gets UNIMPLEMENTED from the gRPC server itself.
  """

  defmodule Service do
    @moduledoc false
    use GRPC.Service, name: "InternalApi.Loghub.Loghub"

    rpc(
      :GetLogEvents,
      InternalApi.Loghub.GetLogEventsRequest,
      InternalApi.Loghub.GetLogEventsResponse
    )
  end

  defmodule Server do
    @moduledoc false
    use GRPC.Server, service: Support.LegacyLoghub.Service

    def get_log_events(req, stream) do
      fun = Application.fetch_env!(:pipelines_api, :legacy_loghub_fun)
      fun.(req, stream)
    end
  end

  def start(fun) do
    Application.put_env(:pipelines_api, :legacy_loghub_fun, fun)
    {:ok, _pid, port} = GRPC.Server.start(Server, 0)
    port
  end

  def stop, do: GRPC.Server.stop(Server)
end
