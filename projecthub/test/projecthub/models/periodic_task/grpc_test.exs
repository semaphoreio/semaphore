defmodule Projecthub.Models.PeriodicTask.GrpcTest do
  use Projecthub.DataCase
  alias Projecthub.Models.PeriodicTask

  alias Support.FakeServices.PeriodicSchedulerService, as: PeriodicService
  alias InternalApi.PeriodicScheduler, as: API
  alias InternalApi.Status

  describe "list/1" do
    test "when request fails it returns an error" do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid argument"}} =
               PeriodicTask.GRPC.list("12345678-1234-5678-1234-567812345678")
    end

    test "when request succeeds with empty list it returns an empty list" do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(code: :OK), periodics: [])
      end)

      assert {:ok, []} = PeriodicTask.GRPC.list("12345678-1234-5678-1234-567812345678")
    end

    test "when request succeeds with periodics it returns a list" do
      periodic = grpc_periodic()

      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(code: :OK), periodics: [periodic])
      end)

      assert {:ok, [^periodic]} = PeriodicTask.GRPC.list("12345678-1234-5678-1234-567812345678")
    end
  end

  describe "upsert/3" do
    test "when request fails it returns an error" do
      FunRegistry.set!(PeriodicService, :apply, fn _req, _stream ->
        API.ApplyResponse.new(status: Status.new(code: :FAILED_PRECONDITION, message: "Failed precondition"))
      end)

      assert {:error, %GRPC.RPCError{message: "Failed precondition"}} =
               PeriodicTask.GRPC.upsert(yml_definition(), "organization_id", "requester_id")
    end

    test "when request succeeds it retuns periodic ID" do
      FunRegistry.set!(PeriodicService, :apply, fn _req, _stream ->
        API.ApplyResponse.new(status: Status.new(), id: "periodic_id")
      end)

      assert {:ok, "periodic_id"} = PeriodicTask.GRPC.upsert(yml_definition(), "organization_id", "requester_id")
    end
  end

  describe "delete/2" do
    test "when request fails it returns an error" do
      FunRegistry.set!(PeriodicService, :delete, fn _req, _stream ->
        API.ApplyResponse.new(status: Status.new(code: :FAILED_PRECONDITION, message: "Failed precondition"))
      end)

      assert {:error, %GRPC.RPCError{message: "Failed precondition"}} =
               PeriodicTask.GRPC.delete("periodic_id", "requester_id")
    end

    test "when request succeeds it retuns periodic ID" do
      FunRegistry.set!(PeriodicService, :delete, fn req, _stream ->
        API.ApplyResponse.new(status: Status.new(), id: req.id)
      end)

      assert {:ok, "periodic_id"} = PeriodicTask.GRPC.delete("periodic_id", "requester_id")
    end
  end

  defp grpc_periodic do
    API.Periodic.new(
      id: "periodic_id",
      name: "cron",
      recurring: true,
      project_id: "project_id",
      reference: "refs/heads/master",
      at: "0 0 * * *",
      pipeline_file: ".semaphore/cron.yml",
      parameters: [
        API.Periodic.Parameter.new(
          name: "foo",
          description: "description",
          required: true,
          default_value: "option",
          options: ["option1", "option2"]
        )
      ]
    )
  end

  defp yml_definition do
    """
    apiVersion: v1.2
    kind: Schedule
    metadata:
      name: \"cron\"
      id: \"periodic_id\"
    spec:
      project: \"project_name\"
      recurring: true
      at: \"0 0 * * *\"
      reference:
        type: BRANCH
        name: \"master\"
      pipeline_file: \".semaphore/cron.yml\"
      parameters:
      - name: \"foo\"
        description: \"description\"
        required: true
        default_value: \"option\"
        options:
        - \"option1\"
        - \"option2\"
    """
  end
end
