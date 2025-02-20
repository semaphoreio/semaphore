defmodule Router.Tasks.ReplaceTest do
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

    test "POST /projects/:project_id_or_name/tasks/ - endpoint returns 404 when user is not authorized",
         ctx do
      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")

      assert {:ok, %Tesla.Env{status: 404} = env} =
               Tesla.put(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 %{
                   apiVersion: "v2",
                   kind: "Task",
                   spec: %{
                     name: "Task",
                     branch: "master",
                     pipeline_file: "pipeline.yml"
                   }
                 }
               )

      assert %{"message" => "Not Found"} = env.body
    end
  end

  describe "authorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)
      PermissionPatrol.add_permissions(org_id, user_id, ["project.scheduler.manage"])
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id}}
    end

    test "PUT /projects/:project_id_or_name/tasks/:id - endpoint returns 200 when task is created",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          name: "Task",
          description: "Task description",
          branch: "master",
          pipeline_file: "pipeline.yml",
          cron_schedule: "0 0 * * *",
          parameters: [
            %{
              name: "PARAM_NAME",
              description: "Parameter description",
              required: true,
              default_value: "Default value",
              options: ["Option 1", "Option 2"]
            }
          ]
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.put(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 params
               )

      assert %{
               "spec" => %{
                 "name" => "Task",
                 "pipeline_file" => "pipeline.yml",
                 "parameters" => [_]
               }
             } = env.body

      assert %{api_model: %{name: "Task"}} = Support.Stubs.DB.find(:schedulers, scheduler.id)
    end

    test "PUT /projects/:project_id_or_name/tasks/:id - endpoint returns 422 when request is invalid",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          branch: "master",
          pipeline_file: "pipeline.yml",
          cron_schedule: "0 0 * * *",
          parameters: [
            %{
              name: "PARAM_NAME",
              description: "Parameter description",
              required: true,
              default_value: "Default value",
              options: ["Option 1", "Option 2"]
            }
          ]
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")

      assert {:ok, %Tesla.Env{status: 422} = env} =
               Tesla.put(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 params
               )

      assert %{"errors" => [%{"detail" => "Missing field: name"}]} = env.body
    end

    test "PUT /projects/:project_id_or_name/tasks/:id - endpoint returns 404 when task is not owned by requester org",
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
        kind: "Task",
        spec: %{
          name: "Task",
          branch: "master",
          pipeline_file: "pipeline.yml"
        }
      }

      assert {:ok, %Tesla.Env{status: 404}} =
               Tesla.put(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
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
