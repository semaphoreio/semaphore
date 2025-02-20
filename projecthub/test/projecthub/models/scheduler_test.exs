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
              branch: "master",
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

      apply_response =
        InternalApi.PeriodicScheduler.ApplyResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :apply, fn req, _s ->
        assert req.organization_id == project.organization_id
        assert req.requester_id == "requester_id"

        assert req.yml_definition == """
               apiVersion: v1.0
               kind: Schedule
               metadata:
                 name: \"cron\"
                 id: \"12345678-1234-5678-1234-567812345678\"
               spec:
                 project: \"#{project.name}\"
                 branch: \"master\"
                 at: \"*\"
                 pipeline_file: \".semaphore/cron.yml\"
               """

        apply_response
      end)

      {:ok, nil} = Scheduler.apply(scheduler, project, "requester_id")
    end

    test "it applies scheduler paused with correct params and returns ok" do
      scheduler = %Scheduler{
        id: "12345678-1234-5678-1234-567812345678",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml",
        status: :STATUS_ACTIVE
      }

      {:ok, project} = Support.Factories.Project.create()

      apply_response =
        InternalApi.PeriodicScheduler.ApplyResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :apply, fn req, _s ->
        assert req.organization_id == project.organization_id
        assert req.requester_id == "requester_id"

        assert req.yml_definition == """
               apiVersion: v1.0
               kind: Schedule
               metadata:
                 name: \"cron\"
                 id: \"12345678-1234-5678-1234-567812345678\"
               spec:
                 project: \"#{project.name}\"
                 branch: \"master\"
                 at: \"*\"
                 pipeline_file: \".semaphore/cron.yml\"
                 paused: false
               """

        apply_response
      end)

      {:ok, nil} = Scheduler.apply(scheduler, project, "requester_id")
    end

    test "when scheduler is new => send yml with empty ID" do
      scheduler = %Scheduler{
        id: "",
        name: "cron",
        branch: "master",
        at: "*",
        pipeline_file: ".semaphore/cron.yml",
        status: :STATUS_UNSPECIFIED
      }

      {:ok, project} = Support.Factories.Project.create()

      apply_response =
        InternalApi.PeriodicScheduler.ApplyResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      yml = """
      apiVersion: v1.0
      kind: Schedule
      metadata:
        name: \"#{scheduler.name}\"
        id: \"\"
      spec:
        project: \"#{project.name}\"
        branch: \"#{scheduler.branch}\"
        at: \"#{scheduler.at}\"
        pipeline_file: \"#{scheduler.pipeline_file}\"
      """

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :apply, fn req, _s ->
        assert req.organization_id == project.organization_id
        assert req.requester_id == "requester_id"
        assert req.yml_definition == yml

        apply_response
      end)

      {:ok, nil} = Scheduler.apply(scheduler, project, "requester_id")
    end

    test "when the response is not ok => returns error" do
      scheduler = %Scheduler{id: ""}
      {:ok, project} = Support.Factories.Project.create()

      apply_response =
        InternalApi.PeriodicScheduler.ApplyResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
              message: "Failed precondition"
            )
        )

      FunRegistry.set!(Support.FakeServices.PeriodicSchedulerService, :apply, apply_response)

      {:error, error} = Scheduler.apply(scheduler, project, "requester_id")
      assert error == "Failed precondition"
    end
  end
end
