defmodule PreFlightChecks.GRPC do
  @moduledoc """
  gRPC server supervisor definition
  """

  def child_spec([]) do
    %{
      id: PreFlightChecks.GRPC,
      start: {
        GRPC.Server.Supervisor,
        :start_link,
        endpoints()
      }
    }
  end

  defp endpoints do
    [{[PreFlightChecks.GRPC.Server, PreFlightChecks.GRPC.HealthCheck], 50_051}]
  end
end
