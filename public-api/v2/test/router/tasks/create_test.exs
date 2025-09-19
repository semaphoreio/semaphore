defmodule Router.Tasks.CreateTest do
  use PublicAPI.Case

  setup do
    Support.Stubs.reset()
  end

  describe "unauthorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id}}
    end

    test "POST /tasks - endpoint returns 404 when user is not authorized", ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          name: "Task",
          description: "Task description",
          reference: %{
            type: "branch",
            name: "master"
          },
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

      assert {:ok, %Tesla.Env{status: 404} = env} =
               Tesla.post(http_client(ctx), "/projects/#{ctx.project_id}/tasks", params)

      assert %{"message" => "Project not found"} = env.body
    end
  end

  describe "authorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

      org = Support.Stubs.Organization.create(org_id: org_id, name: "Organization")
      user = Support.Stubs.User.create(user_id: user_id, name: "User")
      project = Support.Stubs.Project.create(org, user, id: project_id, name: "Project")

      PermissionPatrol.add_permissions(org_id, user_id, ["project.scheduler.manage"])
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project.id}}
    end

    test "POST /tasks - endpoint returns 200 when task is created", ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          name: "Task",
          description: "Task description",
          reference: %{
            type: "branch",
            name: "master"
          },
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

      assert {:ok, %Tesla.Env{status: 200, body: %{"metadata" => %{"id" => task_id}}}} =
               Tesla.post(http_client(ctx), "/projects/#{ctx.project_id}/tasks", params)

      assert Support.Stubs.DB.find(:schedulers, task_id)
      assert {:ok, _} = UUID.info(task_id)
    end

    test "POST /tasks - endpoint returns 200 when task is created with reference structure for branch",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          name: "Task with Reference",
          description: "Task description",
          reference: %{
            type: "branch",
            name: "feature-branch"
          },
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

      assert {:ok, %Tesla.Env{status: 200, body: %{"metadata" => %{"id" => task_id}}}} =
               Tesla.post(http_client(ctx), "/projects/#{ctx.project_id}/tasks", params)

      assert Support.Stubs.DB.find(:schedulers, task_id)
      assert {:ok, _} = UUID.info(task_id)
    end

    test "POST /tasks - endpoint returns 200 when task is created with reference structure for tag",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          name: "Task with Tag",
          description: "Task description",
          reference: %{
            type: "tag",
            name: "v1.0.0"
          },
          pipeline_file: "pipeline.yml",
          cron_schedule: "0 0 * * *",
          parameters: []
        }
      }

      assert {:ok, %Tesla.Env{status: 200, body: %{"metadata" => %{"id" => task_id}}}} =
               Tesla.post(http_client(ctx), "/projects/#{ctx.project_id}/tasks", params)

      assert Support.Stubs.DB.find(:schedulers, task_id)
      assert {:ok, _} = UUID.info(task_id)
    end

    test "POST /tasks - endpoint returns 200 when task is created with reference structure",
         ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          name: "Task with Reference",
          description: "Task description",
          reference: %{
            type: "branch",
            name: "main"
          },
          pipeline_file: "pipeline.yml",
          cron_schedule: "0 0 * * *",
          parameters: []
        }
      }

      assert {:ok, %Tesla.Env{status: 200, body: %{"metadata" => %{"id" => task_id}}}} =
               Tesla.post(http_client(ctx), "/projects/#{ctx.project_id}/tasks", params)

      task = Support.Stubs.DB.find(:schedulers, task_id)
      assert task
      assert task.api_model.reference == "refs/heads/main"
    end

    test "POST /tasks - endpoint returns 422 when request is invalid", ctx do
      params = %{
        apiVersion: "v2",
        kind: "Task",
        spec: %{
          name: "Test",
          reference: %{
            type: "branch",
            name: "master"
          },
          pipeline_file: "pipeline.yml",
          cron_schedule: "0 0 * * *",
          parameters: [
            %{
              name: "Parameter name",
              description: "Parameter description",
              required: true,
              default_value: "Default value",
              options: ["Option 1", "Option 2"]
            }
          ]
        }
      }

      assert {:ok, %Tesla.Env{status: 422} = env} =
               Tesla.post(http_client(ctx), "/projects/#{ctx.project_id}/tasks", params)

      assert %{"errors" => [%{"detail" => "Invalid format. Expected ~r/^[A-Z_]{1,}[A-Z0-9_]*$/"}]} =
               env.body
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
