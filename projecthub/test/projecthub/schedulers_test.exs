defmodule Projecthub.SchedulersTest do
  use Projecthub.DataCase
  alias Projecthub.Schedulers
  alias Projecthub.Models.Scheduler
  alias InternalApi.PeriodicScheduler, as: API
  alias InternalApi.Status
  alias Support.FakeServices.PeriodicSchedulerService, as: PeriodicService

  describe ".update" do
    test "sends each scheduler as a periodic definition and returns ok" do
      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/scheduler.yml"
      }

      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        assert req.project_id == project.id
        assert req.organization_id == project.organization_id
        assert req.requester_id == "requester_id"

        [definition] = req.periodics
        assert definition.id == scheduler.id
        assert definition.name == scheduler.name
        assert definition.at == scheduler.at
        assert definition.reference == "refs/heads/master"
        assert definition.pipeline_file == scheduler.pipeline_file
        assert definition.recurring == true

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [API.Periodic.new(id: scheduler.id)],
          deleted_ids: []
        )
      end)

      assert {:ok, nil} = Schedulers.update(project, [scheduler], "requester_id")
    end

    test "an empty list deletes all schedulers via the bulk RPC" do
      {:ok, project} = Support.Factories.Project.create()

      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        assert req.periodics == []

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [],
          deleted_ids: ["12345678-1234-5678-1234-567812345678"]
        )
      end)

      assert {:ok, nil} = Schedulers.update(project, [], "requester_id")
    end

    test "when the bulk RPC fails the error is returned and no local fallback runs" do
      # Regression test: invalid scheduler payload must not leave the project
      # with destroyed scheduler state. The fix routes update/3 through a single
      # transactional RPC, so an error here means zero rows changed on the
      # remote side and no other gRPC calls are made on the projecthub side.
      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "not a cron",
        pipeline_file: ".semaphore/cron.yml"
      }

      test_pid = self()

      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        send(test_pid, :list_called)
        API.ListResponse.new(status: Status.new(), periodics: [])
      end)

      FunRegistry.set!(PeriodicService, :delete, fn _req, _stream ->
        send(test_pid, :delete_called)
        API.DeleteResponse.new(status: Status.new())
      end)

      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn _req, _stream ->
        API.BulkUpsertAndPruneResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid cron"))
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid cron"}} = Schedulers.update(project, [scheduler], "requester_id")

      refute_received :list_called
      refute_received :delete_called
    end

    test "when an incoming scheduler has an invalid cron => returns error and does not delete or apply" do
      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "abcdef01-1234-5678-1234-567812345678",
        name: "broken",
        branch: "master",
        at: "not a valid cron",
        pipeline_file: ".semaphore/scheduler.yml"
      }

      schedulers = [scheduler]

      with_mock Scheduler, [:passthrough],
        delete: fn _s, _r -> flunk("Scheduler.delete should not be called for invalid cron") end,
        apply: fn _s, _p, _r -> flunk("Scheduler.apply should not be called for invalid cron") end do
        assert {:error, "Invalid cron expression in task 'broken': " <> _} =
                 Schedulers.update(project, schedulers, "requester_id")
      end
    end
  end

  describe ".delete_all" do
    test "deletes all schedulers via the bulk RPC" do
      {:ok, project} = Support.Factories.Project.create()

      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        assert req.periodics == []
        assert req.project_id == project.id

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [],
          deleted_ids: ["12345678-1234-5678-1234-567812345678"]
        )
      end)

      assert {:ok, nil} = Schedulers.delete_all(project, "requester_id")
    end
  end
end
