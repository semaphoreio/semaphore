defmodule Router.Tasks.DeleteTest do
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

    test "DELETE /projects/:project_id_or_name/tasks/:id - endpoint returns 404 when user is not authorized",
         ctx do
      assert {:ok, %Tesla.Env{status: 404} = env} =
               Tesla.delete(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> UUID.uuid4()
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

    test "DELETE /projects/:project_id_or_name/tasks/:id - endpoint returns 200 when task is deleted",
         ctx do
      scheduler = Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler")
      scheduler_id = scheduler.id

      assert {:ok, %Tesla.Env{status: 200, body: %{}}} =
               Tesla.delete(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler_id
               )

      assert Support.Stubs.DB.find(:schedulers, scheduler_id) == nil
    end

    test "DELETE /projects/:project_id_or_name/tasks/:id - endpoint returns 422 when ID is not UUID",
         ctx do
      assert {:ok, %Tesla.Env{status: 422} = env} =
               Tesla.delete(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> "id-which-is-not-UUID"
               )

      assert %{"message" => "Validation Failed"} = env.body
    end

    test "DELETE /projects/:project_id_or_name/tasks/:id - endpoint returns 404 when task is not found",
         ctx do
      assert {:ok, %Tesla.Env{status: 404, body: %{"message" => "Not found"}}} =
               Tesla.delete(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> UUID.uuid4()
               )
    end

    test "DELETE /projects/:project_id_or_name/tasks/:id - endpoint returns 404 when project is not owned by requester",
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
      scheduler_id = scheduler.id

      assert {:ok, %Tesla.Env{status: 404, body: %{"message" => _}}} =
               Tesla.delete(
                 http_client(ctx),
                 "/projects/#{ctx.project_id}/tasks/" <> scheduler_id
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
