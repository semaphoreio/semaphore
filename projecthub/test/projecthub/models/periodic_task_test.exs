defmodule Projecthub.Models.PeriodicTaskTest do
  use Projecthub.DataCase

  alias Projecthub.Models.PeriodicTask
  alias Projecthub.Models.Project
  alias InternalApi.PeriodicScheduler, as: API
  alias InternalApi.Status
  alias Support.FakeServices.PeriodicSchedulerService, as: PeriodicService

  setup_all do
    {:ok,
     project: %Project{
       id: "project_id",
       name: "project_name",
       organization_id: "organization_id"
     },
     periodic1:
       periodic_from_grpc(%{
         id: "1",
         name: "task1",
         recurring: false,
         at: "",
         reference: "",
         pipeline_file: ""
       }),
     periodic2:
       periodic_from_grpc(%{
         id: "2",
         name: "task2",
         parameters: [
           %{name: "param1", required: true, default_value: "default"},
           %{name: "param2", required: false, default_value: "default"},
           %{name: "param3", required: false, options: ["op1", "op2"]}
         ]
       }),
     periodic3:
       periodic_from_grpc(%{
         id: "3",
         name: "task3",
         recurring: false,
         at: "",
         reference: "refs/heads/develop",
         pipeline_file: ".semaphore/semaphore.yml",
         paused: true
       })}
  end

  describe "construct/1" do
    test "when given a list then returns a list of tasks", ctx do
      assert [%PeriodicTask{id: "1"}, %PeriodicTask{id: "2"}, %PeriodicTask{id: "3"}] =
               PeriodicTask.construct([ctx.periodic1, ctx.periodic2, ctx.periodic3], "proj_name")
    end

    test "when given a map then returns a task struct", ctx do
      assert %PeriodicTask{
               id: "1",
               name: "task1",
               description: "test description",
               status: :STATUS_ACTIVE,
               recurring: false,
               at: "",
               branch: "",
               pipeline_file: "",
               project_name: "project_name",
               parameters: []
             } = PeriodicTask.construct(ctx.periodic1, "project_name")
    end

    test "correctly maps parameters", ctx do
      assert task = PeriodicTask.construct(ctx.periodic2, "project_name")

      assert task.parameters == [
               %{
                 name: "param1",
                 description: "",
                 required: true,
                 default_value: "default",
                 options: []
               },
               %{
                 name: "param2",
                 description: "",
                 required: false,
                 default_value: "default",
                 options: []
               },
               %{
                 name: "param3",
                 description: "",
                 required: false,
                 default_value: "",
                 options: ["op1", "op2"]
               }
             ]
    end

    test "correctly maps inactive status", ctx do
      assert %PeriodicTask{
               id: "3",
               name: "task3",
               description: "test description",
               status: :STATUS_INACTIVE,
               recurring: false,
               at: "",
               branch: "develop",
               pipeline_file: ".semaphore/semaphore.yml",
               project_name: "project_name",
               parameters: []
             } = PeriodicTask.construct(ctx.periodic3, "project_name")
    end
  end

  describe "list/1" do
    test "when project has no tasks then returns an empty list", _ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(), periodics: [])
      end)

      assert {:ok, []} = PeriodicTask.list(%Project{id: "1", name: "project"})
    end

    test "when project has tasks then returns a list of them", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(
          status: Status.new(),
          periodics: [ctx.periodic1, ctx.periodic2, ctx.periodic3]
        )
      end)

      assert {:ok, [%PeriodicTask{id: "1"}, %PeriodicTask{id: "2"}, %PeriodicTask{id: "3"}]} =
               PeriodicTask.list(%Project{id: "1", name: "project"})
    end

    test "when error occurs then returns an error tuple", _ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(
          status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid project ID"),
          periodics: []
        )
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid project ID"}} =
               PeriodicTask.list(%Project{id: "1", name: "project"})
    end
  end

  describe "upsert/3" do
    test "when task is successfully upserted then returns the periodic ID", ctx do
      FunRegistry.set!(PeriodicService, :apply, fn _req, _stream ->
        API.ApplyResponse.new(status: Status.new(), id: "periodic_id")
      end)

      assert {:ok, "periodic_id"} = PeriodicTask.upsert(%PeriodicTask{}, ctx.project, "requester_id")
    end

    test "maps periodic task to yml before applying to gRPC service", ctx do
      FunRegistry.set!(PeriodicService, :apply, fn request, _stream ->
        {:ok, actual} = YamlElixir.read_from_string(request.yml_definition)

        expected = %{
          "apiVersion" => "v1.2",
          "kind" => "Schedule",
          "metadata" => %{
            "name" => "task",
            "id" => "periodic_id",
            "description" => "test description"
          },
          "spec" => %{
            "project" => "project_name",
            "recurring" => true,
            "paused" => false,
            "at" => "0 0 * * *",
            "reference" => %{
              "type" => "BRANCH",
              "name" => "master"
            },
            "pipeline_file" => "pipeline.yml"
          }
        }

        assert actual == expected
        assert request.organization_id == "organization_id"
        assert request.requester_id == "requester_id"

        API.ApplyResponse.new(status: Status.new(), id: "periodic_id")
      end)

      assert {:ok, "periodic_id"} = PeriodicTask.upsert(periodic_task(id: "periodic_id"), ctx.project, "requester_id")
    end

    test "when error occurs then returns an error tuple", ctx do
      FunRegistry.set!(PeriodicService, :apply, fn _req, _stream ->
        API.ApplyResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid argument"}} =
               PeriodicTask.upsert(periodic_task(), ctx.project, "requester_id")
    end
  end

  describe "delete/2" do
    test "when task is successfully deleted then returns the periodic ID" do
      FunRegistry.set!(PeriodicService, :delete, fn request, _stream ->
        API.DeleteResponse.new(status: Status.new(), id: request.id)
      end)

      assert {:ok, "periodic_id"} = PeriodicTask.delete(periodic_task(id: "periodic_id"), "requester_id")
    end

    test "when error occurs then returns an error tuple" do
      FunRegistry.set!(PeriodicService, :delete, fn _req, _stream ->
        API.DeleteResponse.new(status: Status.new(code: :FAILED_PRECONDITION, message: "Failed precondition"))
      end)

      assert {:error, %GRPC.RPCError{message: "Failed precondition"}} =
               PeriodicTask.delete(%PeriodicTask{id: "1"}, "requester_id")
    end
  end

  describe "update_all/3" do
    setup do
      FunRegistry.set!(PeriodicService, :apply, fn req, _stream ->
        API.ApplyResponse.new(
          status: Status.new(),
          id:
            req.yml_definition
            |> YamlElixir.read_from_string!()
            |> get_in(["metadata", "id"])
        )
      end)

      FunRegistry.set!(PeriodicService, :delete, fn req, _stream ->
        API.DeleteResponse.new(status: Status.new(), id: req.id)
      end)
    end

    test "deletes tasks that are not in the new list", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(
          status: Status.new(),
          periodics: [ctx.periodic1, ctx.periodic2, ctx.periodic3]
        )
      end)

      new_tasks = [PeriodicTask.construct(ctx.periodic1, "project_name"), periodic_task(id: "4")]

      assert {:ok, upserted: ["4", "1"], deleted: ["3", "2"]} =
               PeriodicTask.update_all(ctx.project, new_tasks, "requester_id")
    end

    test "upserts tasks that are not in the old list", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(), periodics: [ctx.periodic3])
      end)

      new_tasks = [
        PeriodicTask.construct(ctx.periodic1, "project_name"),
        PeriodicTask.construct(ctx.periodic2, "project_name"),
        periodic_task(id: "4")
      ]

      assert {:ok, upserted: ["4", "2", "1"], deleted: ["3"]} =
               PeriodicTask.update_all(ctx.project, new_tasks, "requester_id")
    end

    test "when no tasks are configured then upserts all tasks", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(), periodics: [ctx.periodic3])
      end)

      new_tasks = [
        periodic_task(id: "1"),
        periodic_task(id: "2"),
        periodic_task(id: "3")
      ]

      assert {:ok, upserted: ["3", "2", "1"], deleted: []} =
               PeriodicTask.update_all(ctx.project, new_tasks, "requester_id")
    end

    test "when no tasks are given then deletes all tasks", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(
          status: Status.new(),
          periodics: [ctx.periodic1, ctx.periodic2, ctx.periodic3]
        )
      end)

      assert {:ok, upserted: [], deleted: ["3", "2", "1"]} = PeriodicTask.update_all(ctx.project, [], "requester_id")
    end

    test "returns an errors tuple when an error from list occurs", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid argument"}} =
               PeriodicTask.update_all(ctx.project, [periodic_task(id: "1")], "requester_id")
    end

    test "returns an errors tuple when an error from apply occurs", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(), periodics: [])
      end)

      FunRegistry.set!(PeriodicService, :apply, fn _req, _stream ->
        API.ApplyResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid argument"}} =
               PeriodicTask.update_all(ctx.project, [periodic_task(id: "1")], "requester_id")
    end

    test "returns an errors tuple when an error from delete occurs", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(), periodics: [ctx.periodic2])
      end)

      FunRegistry.set!(PeriodicService, :delete, fn _req, _stream ->
        API.DeleteResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid argument"}} =
               PeriodicTask.update_all(ctx.project, [periodic_task(id: "1")], "requester_id")
    end
  end

  describe "delete_all/2" do
    test "deletes all tasks for a project", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(
          status: Status.new(),
          periodics: [ctx.periodic1, ctx.periodic2, ctx.periodic3]
        )
      end)

      FunRegistry.set!(PeriodicService, :delete, fn req, _stream ->
        API.DeleteResponse.new(status: Status.new(), id: req.id)
      end)

      assert {:ok, ["3", "2", "1"]} = PeriodicTask.delete_all(ctx.project, "requester_id")
    end

    test "returns an errors tuple when an error from list occurs", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
      end)

      FunRegistry.set!(PeriodicService, :delete, fn req, _stream ->
        API.DeleteResponse.new(status: Status.new(), id: req.id)
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid argument"}} =
               PeriodicTask.delete_all(ctx.project, "requester_id")
    end

    test "returns an errors tuple when an error from delete occurs", ctx do
      FunRegistry.set!(PeriodicService, :list, fn _req, _stream ->
        API.ListResponse.new(
          status: Status.new(),
          periodics: [ctx.periodic1, ctx.periodic2, ctx.periodic3]
        )
      end)

      FunRegistry.set!(PeriodicService, :delete, fn _req, _stream ->
        API.DeleteResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid argument"}} =
               PeriodicTask.delete_all(ctx.project, "requester_id")
    end
  end

  defp periodic_from_grpc(params) do
    params = if is_map(params), do: params, else: params |> Enum.to_list() |> Enum.into(%{})
    parameters = Enum.map(get_in(params, [:parameters]) || [], &API.Periodic.Parameter.new/1)

    defaults()
    |> Map.merge(params)
    |> Map.put(:parameters, parameters)
    |> API.Periodic.new()
  end

  defp periodic_task(params \\ %{}) do
    params = if is_map(params), do: params, else: params |> Enum.to_list() |> Enum.into(%{})

    parameters =
      Enum.map(
        get_in(params, [:parameters]) || [],
        &Map.take(&1, ~w(name description required default_value options)a)
      )

    struct(PeriodicTask, defaults() |> Map.merge(params) |> Map.put(:parameters, parameters))
  end

  defp defaults do
    %{
      id: Ecto.UUID.generate(),
      name: "task",
      description: "test description",
      paused: false,
      recurring: true,
      at: "0 0 * * *",
      branch: "master",
      pipeline_file: "pipeline.yml",
      project_name: "project",
      parameters: []
    }
  end
end
