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

      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(), periodics: [])
      end)

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

    test "carries the stored notification skip flags into the definitions" do
      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/scheduler.yml"
      }

      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(
          status: Status.new(),
          periodics: [
            API.Periodic.new(
              id: scheduler.id,
              skip_scheduled_run_notifications: true,
              skip_manual_run_notifications: false
            )
          ]
        )
      end)

      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        [definition] = req.periodics
        assert definition.skip_scheduled_run_notifications == true
        assert definition.skip_manual_run_notifications == false

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

    test "aborts without writing when the stored flags cannot be read" do
      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/scheduler.yml"
      }

      test_pid = self()

      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(code: :INTERNAL, message: "scheduler down"))
      end)

      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn _req, _stream ->
        send(test_pid, :bulk_called)
        API.BulkUpsertAndPruneResponse.new(status: Status.new())
      end)

      assert {:error, :notification_flags_unavailable} = Schedulers.update(project, [scheduler], "requester_id")

      refute_received :bulk_called
    end

    test "when the bulk RPC fails the error is returned and no local fallback runs" do
      # Regression test: invalid scheduler payload must not leave the project
      # with destroyed scheduler state. The fix routes every write through a
      # single transactional RPC, so an error here means zero rows changed on
      # the remote side and no destructive call is made on the projecthub side.
      #
      # A read-only list is allowed: this path carries no notification skip
      # flags of its own, so it reads the stored values to avoid resetting
      # them. It never deletes, and it never writes outside the bulk RPC.
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

      assert_received :list_called
      refute_received :delete_called
    end
  end

  describe ".delete_all" do
    test "lists existing schedulers and deletes each one" do
      {:ok, project} = Support.Factories.Project.create()

      list_response =
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: Status.new(),
          periodics: [
            InternalApi.PeriodicScheduler.Periodic.new(
              id: "12345678-1234-5678-1234-567812345678",
              name: "cron",
              project_id: project.id,
              reference: "refs/heads/master",
              at: "*",
              pipeline_file: ".semaphore/cron.yml"
            )
          ],
          page_size: 1,
          page_number: 1,
          total_entries: 1,
          total_pages: 1
        )

      FunRegistry.set!(PeriodicService, :list, list_response)

      test_pid = self()

      FunRegistry.set!(PeriodicService, :delete, fn req, _stream ->
        send(test_pid, {:delete_called, req.id})
        InternalApi.PeriodicScheduler.DeleteResponse.new(status: Status.new())
      end)

      assert {:ok, nil} = Schedulers.delete_all(project, "requester_id")
      assert_received {:delete_called, "12345678-1234-5678-1234-567812345678"}
    end

    test "swallows individual delete errors and still returns ok" do
      {:ok, project} = Support.Factories.Project.create()

      list_response =
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: Status.new(),
          periodics: [
            InternalApi.PeriodicScheduler.Periodic.new(
              id: "12345678-1234-5678-1234-567812345678",
              name: "cron",
              project_id: project.id,
              reference: "refs/heads/master",
              at: "*",
              pipeline_file: ".semaphore/cron.yml"
            )
          ],
          page_size: 1,
          page_number: 1,
          total_entries: 1,
          total_pages: 1
        )

      FunRegistry.set!(PeriodicService, :list, list_response)

      FunRegistry.set!(PeriodicService, :delete, fn _req, _stream ->
        InternalApi.PeriodicScheduler.DeleteResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "boom"))
      end)

      assert {:ok, nil} = Schedulers.delete_all(project, "requester_id")
    end
  end
end
