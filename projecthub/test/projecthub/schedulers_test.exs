defmodule Projecthub.SchedulersTest do
  use Projecthub.DataCase
  alias Projecthub.Schedulers
  alias Projecthub.Models.Scheduler

  setup do
    list_response =
      InternalApi.PeriodicScheduler.ListResponse.new(
        status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
        periodics: [
          InternalApi.PeriodicScheduler.Periodic.new(
            id: "12345678-1234-5678-1234-567812345678",
            name: "cron",
            project_id: "12345678-1234-5678-1234-567812345678",
            branch: "master",
            at: "*",
            pipeline_file: ".semaphore/cron.yml"
          )
        ],
        page_size: 1,
        page_number: 1,
        total_entries: 1,
        total_pages: 1
      )

    FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :list, list_response)
  end

  describe ".update" do
    test "when a scheduler should be updated => updates it" do
      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/scheduler.yml"
      }

      schedulers = [scheduler]

      with_mock Scheduler, [:passthrough], apply: fn _s, _p, _r -> {:ok, nil} end do
        {:ok, _} = Schedulers.update(project, schedulers, "requester_id")

        assert_called(Scheduler.apply(scheduler, project, "requester_id"))
      end
    end

    test "when a scheduler should be created => creates it" do
      list_response =
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
          periodics: [],
          page_size: 1,
          page_number: 1,
          total_entries: 1,
          total_pages: 1
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :list, list_response)

      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "",
        name: "scheduler",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/scheduler.yml"
      }

      schedulers = [scheduler]

      with_mock Scheduler, [:passthrough], apply: fn _s, _p, _r -> {:ok, nil} end do
        {:ok, _} = Schedulers.update(project, schedulers, "requester_id")

        assert_called(Scheduler.apply(scheduler, project, "requester_id"))
      end
    end

    test "when a scheduler should be deleted => deletes it" do
      {:ok, project} = Support.Factories.Project.create()
      schedulers = []

      deletable_scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml",
        status: :STATUS_ACTIVE
      }

      with_mock Scheduler, [:passthrough], delete: fn _s, _r -> {:ok, nil} end do
        {:ok, _} = Schedulers.update(project, schedulers, "requester_id")

        assert_called(Scheduler.delete(deletable_scheduler, "requester_id"))
      end
    end

    test "when a scheduler is unchanged => updates it" do
      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml"
      }

      schedulers = [scheduler]

      with_mock Scheduler, [:passthrough], apply: fn _s, _p, _r -> {:ok, nil} end do
        {:ok, _} = Schedulers.update(project, schedulers, "requester_id")

        assert_called(Scheduler.apply(scheduler, project, "requester_id"))
      end
    end

    test "when there is a new scheduler with ID specified => creates it in the project scope" do
      list_response =
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
          periodics: [],
          page_size: 1,
          page_number: 1,
          total_entries: 1,
          total_pages: 1
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :list, list_response)

      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "456",
        name: "scheduler",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/scheduler.yml"
      }

      schedulers = [scheduler]

      with_mock Scheduler, [:passthrough], apply: fn _s, _p, _r -> {:ok, nil} end do
        {:ok, _} = Schedulers.update(project, schedulers, "requester_id")

        assert_called(Scheduler.apply(scheduler, project, "requester_id"))
      end
    end

    test "when schedulers deletion fails => returns the error" do
      {:ok, project} = Support.Factories.Project.create()
      schedulers = []

      deletable_scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml",
        status: :STATUS_ACTIVE
      }

      with_mock Scheduler, [:passthrough], delete: fn _s, _r -> {:error, "some error"} end do
        assert {:error, "some error"} = Schedulers.update(project, schedulers, "requester_id")

        assert_called(Scheduler.delete(deletable_scheduler, "requester_id"))
      end
    end

    test "when schedulers update or create fails => returns the error" do
      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :delete, fn _req, _s ->
        InternalApi.PeriodicScheduler.DeleteResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )
      end)

      {:ok, project} = Support.Factories.Project.create()

      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml"
      }

      schedulers = [scheduler]

      with_mock Scheduler, [:passthrough], apply: fn _s, _p, _r -> {:error, "some apply error"} end do
        assert {:error, "some apply error"} = Schedulers.update(project, schedulers, "requester_id")

        assert_called(Scheduler.apply(scheduler, project, "requester_id"))
      end
    end
  end

  describe ".delete_all" do
    test "deletes all listed schedulers for the project" do
      {:ok, project} = Support.Factories.Project.create()

      listed_scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml",
        status: :STATUS_ACTIVE
      }

      with_mock Scheduler, [:passthrough], delete: fn _s, _r -> {:ok, nil} end do
        {:ok, _} = Schedulers.delete_all(project, "requester_id")

        assert_called(Scheduler.delete(listed_scheduler, "requester_id"))
      end
    end
  end
end
