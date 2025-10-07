defmodule Router.Tasks.TriggerTest do
  use PublicAPI.Case

  setup do
    Support.Stubs.reset()
  end

  describe "unauthorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id}}
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 404 when user is not authorized",
         ctx do
      assert {:ok, %Tesla.Env{status: 404} = env} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{UUID.uuid4()}/triggers",
                 %{apiVersion: "v2", kind: "TaskTrigger", spec: %{}}
               )

      assert %{"message" => "Not Found"} = env.body
    end
  end

  describe "authorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)
      PermissionPatrol.add_permissions(org_id, user_id, ["project.scheduler.run_manually"])
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id}}
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 200 when task is created",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "TaskTrigger",
        spec: %{
          reference: %{
            type: "branch",
            name: "master"
          },
          pipeline_file: ".semaphore/semaphore.yml",
          parameters: [
            %{name: "FIRST_PARAM", value: "first_value"}
          ]
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id)

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{scheduler.id}/triggers",
                 params
               )

      assert %{"metadata" => %{"workflow_id" => workflow_id}} = env.body
      assert {:ok, _} = UUID.info(workflow_id)

      assert [_] = Support.Stubs.DB.find_all_by(:triggers, :periodic_id, scheduler.id)
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 200 with empty spec",
         ctx do
      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id)

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{scheduler.id}/triggers",
                 %{apiVersion: "v2", kind: "TaskTrigger", spec: %{}}
               )

      assert %{"metadata" => %{"workflow_id" => workflow_id}} = env.body
      assert {:ok, _} = UUID.info(workflow_id)

      assert [_] = Support.Stubs.DB.find_all_by(:triggers, :periodic_id, scheduler.id)
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 200 with new reference structure for branch",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "TaskTrigger",
        spec: %{
          reference: %{
            type: "branch",
            name: "feature-branch"
          },
          pipeline_file: ".semaphore/semaphore.yml",
          parameters: [
            %{name: "FIRST_PARAM", value: "first_value"}
          ]
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id)

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{scheduler.id}/triggers",
                 params
               )

      assert %{"metadata" => %{"workflow_id" => workflow_id}} = env.body
      assert {:ok, _} = UUID.info(workflow_id)

      assert [_] = Support.Stubs.DB.find_all_by(:triggers, :periodic_id, scheduler.id)
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 200 with new reference structure for tag",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "TaskTrigger",
        spec: %{
          reference: %{
            type: "tag",
            name: "v1.0.0"
          },
          pipeline_file: ".semaphore/semaphore.yml",
          parameters: [
            %{name: "FIRST_PARAM", value: "first_value"}
          ]
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id)

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{scheduler.id}/triggers",
                 params
               )

      assert %{"metadata" => %{"workflow_id" => workflow_id}} = env.body
      assert {:ok, _} = UUID.info(workflow_id)

      assert [_] = Support.Stubs.DB.find_all_by(:triggers, :periodic_id, scheduler.id)
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 200 with reference structure",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "TaskTrigger",
        spec: %{
          reference: %{
            type: "branch",
            name: "master"
          },
          pipeline_file: ".semaphore/semaphore.yml"
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id)

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{scheduler.id}/triggers",
                 params
               )

      assert %{"metadata" => %{"workflow_id" => workflow_id}} = env.body
      assert {:ok, _} = UUID.info(workflow_id)

      assert [_] = Support.Stubs.DB.find_all_by(:triggers, :periodic_id, scheduler.id)
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 404 when periodic does not exist",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "TaskTrigger",
        spec: %{
          reference: %{
            type: "branch",
            name: "master"
          },
          pipeline_file: ".semaphore/semaphore.yml",
          parameters: [
            %{name: "FIRST_PARAM", value: "first_value"}
          ]
        }
      }

      assert {:ok, %Tesla.Env{status: 404} = env} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{UUID.uuid4()}/triggers",
                 params
               )

      assert %{"message" => "Not found"} = env.body
    end

    test "POST /projects/:project_id_or_name/tasks/:id/triggers - endpoint returns 404 when periodic is not owned by requester org",
         ctx do
      wrong_owner = UUID.uuid4()

      GrpcMock.stub(SchedulerMock, :describe, fn req, _ ->
        alias Support.Stubs.DB
        periodic = DB.find(:schedulers, req.id)

        %InternalApi.PeriodicScheduler.DescribeResponse{
          status: %InternalApi.Status{code: :OK},
          periodic: %{periodic.api_model | project_id: wrong_owner}
        }
      end)

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")

      params = %{
        apiVersion: "v2",
        kind: "TaskTrigger",
        spec: %{
          reference: %{
            type: "branch",
            name: "master"
          },
          pipeline_file: ".semaphore/semaphore.yml"
        }
      }

      assert {:ok, %Tesla.Env{status: 404}} =
               Tesla.post(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/#{scheduler.id}/triggers",
                 params
               )
    end
  end

  defp http_client(ctx) do
    middleware = [
      {Tesla.Middleware.Headers,
       [
         {"content-type", "application/json"},
         {"x-semaphore-org-id", ctx.org_id},
         {"x-semaphore-user-id", ctx.user_id}
       ]},
      {Tesla.Middleware.BaseUrl, "http://localhost:4004"},
      Tesla.Middleware.JSON
    ]

    adapter = {Tesla.Adapter.Hackney, [recv_timeout: 30_000]}
    Tesla.client(middleware, adapter)
  end
end
