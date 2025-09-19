# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Projecthub.Models.SchedulerTest do
  use Projecthub.DataCase
  alias Projecthub.Models.Scheduler

  describe ".list" do
    test "it lists schedulers with correct params" do
      {:ok, project} = Support.Factories.Project.create()

      list_response =
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
          periodics: []
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :list, fn req, _s ->
        assert req.project_id == project.id

        list_response
      end)

      {:ok, _} = Scheduler.list(project)
    end

    test "when the response is ok => constructs scheduler list" do
      {:ok, project} = Support.Factories.Project.create()

      list_response =
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
          periodics: [
            InternalApi.PeriodicScheduler.Periodic.new(
              id: "12345678-1234-5678-1234-567812345678",
              name: "cron",
              project_id: "12345678-1234-5678-1234-567812345678",
              reference: "refs/heads/master",
              at: "*",
              pipeline_file: ".semaphore/cron.yml",
              paused: false
            )
          ],
          page_size: 1,
          page_number: 1,
          total_entries: 1,
          total_pages: 1
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :list, list_response)

      {:ok, schedulers} = Scheduler.list(project)

      assert schedulers == [
               %Scheduler{
                 id: "12345678-1234-5678-1234-567812345678",
                 name: "cron",
                 branch: "master",
                 at: "*",
                 pipeline_file: ".semaphore/cron.yml",
                 status: :STATUS_ACTIVE
               }
             ]
    end

    test "when the response is not ok => returns error" do
      {:ok, project} = Support.Factories.Project.create()

      list_response =
        InternalApi.PeriodicScheduler.ListResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
              message: "Invalid argument"
            )
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :list, list_response)

      {:error, error} = Scheduler.list(project)
      assert error == "Invalid argument"
    end
  end

  describe ".delete" do
    test "it deletes scheduler with correct params and returns ok" do
      scheduler = %Scheduler{id: "12345678-1234-5678-1234-567812345678"}

      delete_response =
        InternalApi.PeriodicScheduler.DeleteResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :delete, fn req, _s ->
        assert req.id == scheduler.id
        assert req.requester == "requester_id"

        delete_response
      end)

      {:ok, nil} = Scheduler.delete(scheduler, "requester_id")
    end

    test "when the response is not ok => returns error" do
      scheduler = %Scheduler{id: "12345678-1234-5678-1234-567812345678"}

      delete_response =
        InternalApi.PeriodicScheduler.DeleteResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
              message: "Internal error"
            )
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :delete, delete_response)

      {:error, error} = Scheduler.delete(scheduler, "requester_id")
      assert error == "Internal error"
    end
  end

  describe ".apply" do
    test "it applies scheduler rules with correct params and returns ok" do
      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml"
      }

      {:ok, project} = Support.Factories.Project.create()

      persist_response =
        InternalApi.PeriodicScheduler.PersistResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :persist, fn req, _s ->
        assert req.organization_id == project.organization_id
        assert req.requester_id == "requester_id"
        assert req.id == scheduler.id
        assert req.name == scheduler.name
        assert req.description == ""
        assert req.recurring == true
        assert req.state == :UNCHANGED
        assert req.project_name == project.name
        assert req.reference == "refs/heads/master"
        assert req.pipeline_file == scheduler.pipeline_file
        assert req.at == scheduler.at
        assert req.parameters == []
        assert req.project_id == project.id

        persist_response
      end)

      {:ok, nil} = Scheduler.apply(scheduler, project, "requester_id")
    end

    test "it applies scheduler with tag reference correctly" do
      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "refs/tags/v1.0.0",
        at: "*",
        pipeline_file: ".semaphore/cron.yml",
        status: :STATUS_ACTIVE
      }

      {:ok, project} = Support.Factories.Project.create()

      persist_response =
        InternalApi.PeriodicScheduler.PersistResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :persist, fn req, _s ->
        assert req.organization_id == project.organization_id
        assert req.requester_id == "requester_id"
        assert req.reference == "refs/tags/v1.0.0"

        persist_response
      end)

      {:ok, nil} = Scheduler.apply(scheduler, project, "requester_id")
    end

    test "when scheduler is new => send request with empty ID" do
      scheduler = %Scheduler{
        id: "",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml",
        status: :STATUS_UNSPECIFIED
      }

      {:ok, project} = Support.Factories.Project.create()

      persist_response =
        InternalApi.PeriodicScheduler.PersistResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :persist, fn req, _s ->
        assert req.organization_id == project.organization_id
        assert req.requester_id == "requester_id"
        assert req.id == ""
        assert req.name == scheduler.name
        assert req.reference == "refs/heads/master"
        assert req.at == scheduler.at
        assert req.pipeline_file == scheduler.pipeline_file

        persist_response
      end)

      {:ok, nil} = Scheduler.apply(scheduler, project, "requester_id")
    end

    test "when the response is not ok => returns error" do
      scheduler = %Scheduler{id: ""}
      {:ok, project} = Support.Factories.Project.create()

      persist_response =
        InternalApi.PeriodicScheduler.PersistResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
              message: "Failed precondition"
            )
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :persist, persist_response)

      {:error, error} = Scheduler.apply(scheduler, project, "requester_id")
      assert error == "Failed precondition"
    end
  end

  describe "reference/tag support" do
    test "constructs scheduler with branch reference correctly" do
      raw_scheduler =
        InternalApi.PeriodicScheduler.Periodic.new(
          id: "123",
          name: "test",
          reference: "refs/heads/main",
          at: "*",
          pipeline_file: "test.yml",
          paused: false
        )

      scheduler = Projecthub.Models.Scheduler.construct_list([raw_scheduler]) |> List.first()

      assert scheduler.branch == "main"
      assert scheduler.status == :STATUS_ACTIVE
    end

    test "constructs scheduler with tag reference correctly" do
      raw_scheduler =
        InternalApi.PeriodicScheduler.Periodic.new(
          id: "123",
          name: "test",
          reference: "refs/tags/v1.0.0",
          at: "*",
          pipeline_file: "test.yml",
          paused: false
        )

      scheduler = Projecthub.Models.Scheduler.construct_list([raw_scheduler]) |> List.first()

      assert scheduler.branch == "refs/tags/v1.0.0"
    end

    test "constructs scheduler with pull request reference correctly" do
      raw_scheduler =
        InternalApi.PeriodicScheduler.Periodic.new(
          id: "123",
          name: "test",
          reference: "refs/pull/42/head",
          at: "*",
          pipeline_file: "test.yml",
          paused: false
        )

      scheduler = Projecthub.Models.Scheduler.construct_list([raw_scheduler]) |> List.first()

      assert scheduler.branch == "refs/pull/42/head"
    end

    test "applies scheduler with pull request reference correctly" do
      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "pr-check",
        branch: "refs/pull/42/head",
        at: "*",
        pipeline_file: ".semaphore/pr.yml"
      }

      {:ok, project} = Support.Factories.Project.create()

      persist_response =
        InternalApi.PeriodicScheduler.PersistResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :persist, fn req, _s ->
        assert req.reference == "refs/pull/42/head"
        persist_response
      end)

      {:ok, nil} = Scheduler.apply(scheduler, project, "requester_id")
    end
  end
end
