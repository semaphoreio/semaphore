defmodule Router.Tasks.UpdateTest do
  use PublicAPI.Case

  setup do
    Support.Stubs.reset()
  end

  describe "unauthorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project.id}}
    end

    test "PATCH /projects/:project_id_or_name/tasks/:id - endpoint returns 404 when user is not authorized",
         ctx do
      assert {:ok, %Tesla.Env{status: 404} = env} =
               Tesla.patch(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> UUID.uuid4(),
                 %{"apiVersion" => "v2", "kind" => "Task", "spec" => %{}}
               )

      assert %{"message" => "Not Found"} = env.body
    end
  end

  describe "authorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)
      PermissionPatrol.add_permissions(org_id, user_id, ["project.scheduler.manage"])
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project.id}}
    end

    test "PATCH /projects/:project_id_or_name/tasks/:id - endpoint returns 200 when task is updated",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          reference: %{
            type: "branch",
            name: "develop"
          },
          pipeline_file: "pipeline.yml",
          cron_schedule: ""
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")
      scheduler_id = scheduler.id

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.patch(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 params
               )

      assert %{
               "spec" => %{
                 "name" => "Scheduler",
                 "pipeline_file" => "pipeline.yml",
                 "parameters" => []
               }
             } = env.body

      assert %{
               api_model: %{
                 id: ^scheduler_id,
                 reference: "refs/heads/develop",
                 pipeline_file: "pipeline.yml",
                 at: "",
                 recurring: false
               }
             } = Support.Stubs.DB.find(:schedulers, scheduler.id)
    end

    test "PATCH /projects/:project_id_or_name/tasks/:id - endpoint patches parameters correctly",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
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
      assert scheduler.parameters == []

      assert {:ok, %Tesla.Env{status: 200}} =
               Tesla.patch(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 params
               )

      assert %{
               api_model: %{
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
             } = Support.Stubs.DB.find(:schedulers, scheduler.id)
    end

    test "PATCH /projects/:project_id_or_name/tasks/:id - endpoint updates reference structure for branch",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          reference: %{
            type: "branch",
            name: "feature-branch"
          }
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")
      scheduler_id = scheduler.id

      assert {:ok, %Tesla.Env{status: 200}} =
               Tesla.patch(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 params
               )

      assert %{
               api_model: %{
                 id: ^scheduler_id,
                 reference: "refs/heads/feature-branch"
               }
             } = Support.Stubs.DB.find(:schedulers, scheduler.id)
    end

    test "PATCH /projects/:project_id_or_name/tasks/:id - endpoint updates reference structure for tag",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          reference: %{
            type: "tag",
            name: "v1.0.0"
          }
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")
      scheduler_id = scheduler.id

      assert {:ok, %Tesla.Env{status: 200}} =
               Tesla.patch(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 params
               )

      assert %{
               api_model: %{
                 id: ^scheduler_id,
                 reference: "refs/tags/v1.0.0"
               }
             } = Support.Stubs.DB.find(:schedulers, scheduler.id)
    end

    test "PATCH /projects/:project_id_or_name/tasks/:id - endpoint updates reference structure with partial updates",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          reference: %{
            type: "tag",
            name: "v1.0.0"
          }
        }
      }

      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")
      scheduler_id = scheduler.id

      assert {:ok, %Tesla.Env{status: 200}} =
               Tesla.patch(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler.id,
                 params
               )

      assert %{
               api_model: %{
                 id: ^scheduler_id,
                 reference: "refs/tags/v1.0.0"
               }
             } = Support.Stubs.DB.find(:schedulers, scheduler.id)
    end

    test "PATCH /projects/:project_id_or_name/tasks/:id - endpoint returns 404 when task is not owned by requester",
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
          reference: %{
            type: "branch",
            name: "master"
          },
          pipeline_file: "pipeline.yml"
        }
      }

      assert {:ok, %Tesla.Env{status: 404}} =
               Tesla.patch(
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
