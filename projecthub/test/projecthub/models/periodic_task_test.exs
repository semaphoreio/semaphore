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
    test "sends the full desired set to bulk_upsert_and_prune and returns ids", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        assert req.project_id == ctx.project.id
        assert req.organization_id == ctx.project.organization_id
        assert req.requester_id == "requester_id"
        assert length(req.periodics) == 2

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [
            API.Periodic.new(id: "1"),
            API.Periodic.new(id: "4")
          ],
          deleted_ids: ["3", "2"]
        )
      end)

      new_tasks = [PeriodicTask.construct(ctx.periodic1, "project_name"), periodic_task(id: "4")]

      assert {:ok, upserted: ["1", "4"], deleted: ["3", "2"]} =
               PeriodicTask.update_all(ctx.project, new_tasks, "requester_id")
    end

    test "passes recurring/at/reference/parameters through to the request", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        [first | _] = req.periodics
        assert first.recurring == true
        assert first.at == "0 0 * * *"
        assert first.reference == "refs/heads/master"
        assert first.pipeline_file == "pipeline.yml"

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [API.Periodic.new(id: first.id)],
          deleted_ids: []
        )
      end)

      assert {:ok, _} = PeriodicTask.update_all(ctx.project, [periodic_task(id: "1")], "requester_id")
    end

    test "empty branch falls back to refs/heads/master on the wire", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        [first | _] = req.periodics
        assert first.reference == "refs/heads/master"

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [API.Periodic.new(id: first.id)],
          deleted_ids: []
        )
      end)

      assert {:ok, _} = PeriodicTask.update_all(ctx.project, [periodic_task(id: "1", branch: "")], "requester_id")
    end

    test "nil branch falls back to refs/heads/master on the wire", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        [first | _] = req.periodics
        assert first.reference == "refs/heads/master"

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [API.Periodic.new(id: first.id)],
          deleted_ids: []
        )
      end)

      assert {:ok, _} = PeriodicTask.update_all(ctx.project, [periodic_task(id: "1", branch: nil)], "requester_id")
    end

    test "task status maps to PeriodicDefinition.state on the wire", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        [active, paused, unspecified] = req.periodics
        assert active.state == :ACTIVE
        assert paused.state == :PAUSED
        assert unspecified.state == :UNCHANGED

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: Enum.map(req.periodics, &API.Periodic.new(id: &1.id)),
          deleted_ids: []
        )
      end)

      tasks = [
        periodic_task(id: "1", status: :STATUS_ACTIVE),
        periodic_task(id: "2", status: :STATUS_INACTIVE),
        periodic_task(id: "3", status: :STATUS_UNSPECIFIED)
      ]

      assert {:ok, _} = PeriodicTask.update_all(ctx.project, tasks, "requester_id")
    end

    test "an empty desired set deletes all tasks", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        assert req.periodics == []

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [],
          deleted_ids: ["3", "2", "1"]
        )
      end)

      assert {:ok, upserted: [], deleted: ["3", "2", "1"]} = PeriodicTask.update_all(ctx.project, [], "requester_id")
    end

    test "an error from the bulk RPC is surfaced without any local fallback that could lose data",
         ctx do
      # Regression test for the original bug: when the periodic_scheduler service
      # rejects a batch (e.g. invalid cron), projecthub must NOT perform any local
      # delete-then-upsert sequence — the contract is now a single atomic RPC, so
      # no projecthub-side data-loss path can exist.
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

      assert {:error, %GRPC.RPCError{message: "Invalid cron"}} =
               PeriodicTask.update_all(ctx.project, [periodic_task(id: "1")], "requester_id")

      refute_received :list_called
      refute_received :delete_called
    end
  end

  describe "delete_all/2" do
    test "delegates to bulk_upsert_and_prune with an empty desired set", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn req, _stream ->
        assert req.periodics == []
        assert req.project_id == ctx.project.id

        API.BulkUpsertAndPruneResponse.new(
          status: Status.new(),
          upserted: [],
          deleted_ids: ["3", "2", "1"]
        )
      end)

      assert {:ok, ["3", "2", "1"]} = PeriodicTask.delete_all(ctx.project, "requester_id")
    end

    test "returns an error tuple when the bulk RPC fails", ctx do
      FunRegistry.set!(PeriodicService, :bulk_upsert_and_prune, fn _req, _stream ->
        API.BulkUpsertAndPruneResponse.new(status: Status.new(code: :INVALID_ARGUMENT, message: "Invalid argument"))
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
