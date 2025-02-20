defmodule Zebra.Grpc.HealthCheck.Test do
  use ExUnit.Case, async: false

  alias Grpc.Health.V1.HealthCheckRequest, as: Request
  alias Grpc.Health.V1.HealthCheckResponse, as: Response
  alias Grpc.Health.V1.Health.Stub, as: Stub

  test "no workers are required => SERVING" do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, res} = channel |> Stub.check(Request.new(service: "healthcheck"))
    assert res.status == Response.ServingStatus.value(:SERVING)
  end

  describe "worker required but not started" do
    setup do
      System.put_env("START_JOB_STOPPER", "true")
      on_exit(fn -> System.put_env("START_JOB_STOPPER", "false") end)
    end

    test "check => NOT_SERVING" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = channel |> Stub.check(Request.new(service: "healthcheck"))
      assert res.status == Response.ServingStatus.value(:NOT_SERVING)
    end
  end

  describe "worker required and started" do
    setup do
      System.put_env("START_JOB_STOPPER", "true")

      {:ok, _} =
        Supervisor.start_child(Zebra.Supervisor, %{
          id: Zebra.Workers.JobStopper,
          start: {Zebra.Workers.JobStopper, :start_link, []}
        })

      on_exit(fn ->
        System.put_env("START_JOB_STOPPER", "false")
        :ok = Supervisor.terminate_child(Zebra.Supervisor, Zebra.Workers.JobStopper)
        :ok = Supervisor.delete_child(Zebra.Supervisor, Zebra.Workers.JobStopper)
      end)
    end

    test "check => SERVING" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = channel |> Stub.check(Request.new(service: "healthcheck"))
      assert res.status == Response.ServingStatus.value(:SERVING)
    end
  end
end
