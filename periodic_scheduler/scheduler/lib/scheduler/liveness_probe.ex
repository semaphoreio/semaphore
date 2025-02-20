defmodule Scheduler.LivenessProbe do
  @moduledoc """
  Executed by k8s liveness probe mechanism
  """

  alias LogTee, as: LT
  alias InternalApi.PeriodicScheduler.{PeriodicService, VersionRequest}

  def run do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    request = VersionRequest.new()

    {:ok, _response} =
      channel
      |> PeriodicService.Stub.version(request)
      |> LT.info("Health check - Version call response")
  end
end
