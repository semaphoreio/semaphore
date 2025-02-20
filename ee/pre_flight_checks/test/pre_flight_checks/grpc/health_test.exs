defmodule PreFlightChecks.GRPC.HealthCheckTest do
  alias Grpc.Health.V1, as: Health

  use ExUnit.Case, async: false

  @host "localhost"
  @port 50_051

  test "health check endpoint returns OK response" do
    request = Health.HealthCheckRequest.new()

    assert {:ok, channel} = GRPC.Stub.connect("#{@host}:#{@port}")
    assert {:ok, %Health.HealthCheckResponse{}} = Health.Health.Stub.check(channel, request)
  end
end
