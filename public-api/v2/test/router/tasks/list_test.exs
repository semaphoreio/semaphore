defmodule Router.Tasks.ListTest do
  use PublicAPI.Case

  setup do
    Support.Stubs.reset()
  end

  describe "unauthorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id}}
    end

    test "GET /projects/:project_id_or_name/tasks/ - endpoint returns 404 when user is not authorized",
         ctx do
      assert {:ok, %Tesla.Env{status: 404} = env} =
               Tesla.get(http_client(ctx), "/projects/#{ctx.project_id}/tasks")

      assert %{"message" => "Project not found"} = env.body
    end
  end

  describe "authorized users" do
    setup do
      {org_id, user_id, project_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)
      PermissionPatrol.add_permissions(org_id, user_id, ["project.scheduler.view"])
      {:ok, %{org_id: org_id, user_id: user_id, project_id: project.id}}
    end

    test "GET /projects/:project_id_or_name/tasks/ - endpoint returns 200", ctx do
      for i <- 1..4 do
        Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler #{i}")
      end

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.get(http_client(ctx), "/projects/#{ctx.project_id}/tasks")

      assert MapSet.new(env.body, &get_in(&1, ["spec", "name"])) ==
               MapSet.new([
                 "Scheduler 1",
                 "Scheduler 2",
                 "Scheduler 3",
                 "Scheduler 4"
               ])
    end

    test "GET /projects/:project_id_or_name/tasks/ - endpoint filters project by project_id",
         ctx do
      {project_id_1, project_id_2} = {UUID.uuid4(), UUID.uuid4()}
      Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id_1)
      Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id_2)

      for i <- 1..4 do
        Support.Stubs.Scheduler.create(project_id_1, ctx.user_id, name: "Scheduler #{i}")
      end

      for i <- 5..10 do
        Support.Stubs.Scheduler.create(project_id_2, ctx.user_id, name: "Scheduler #{i}")
      end

      assert {:ok, %Tesla.Env{status: 200, body: body}} =
               Tesla.get(http_client(ctx), "/projects/#{project_id_2}/tasks")

      assert Enum.all?(body, &(get_in(&1, ["metadata", "project_id"]) == project_id_2))
      assert Enum.count(body) == 6
    end

    test "GET /tasks - endpoint returns 422 if page size is too high", ctx do
      assert {:ok, %Tesla.Env{status: 422} = env} =
               Tesla.get(http_client(ctx), "/projects/#{ctx.project_id}/tasks",
                 query: [page_size: 101]
               )

      assert %{"message" => "Validation Failed"} = env.body
    end

    test "GET /projects/:project_id_or_name/tasks/ - endpoint paginates results", ctx do
      schedulers =
        for i <- 1..14 do
          Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id,
            name: "Scheduler #{i |> Integer.to_string() |> String.pad_leading(2, "0")}"
          )
        end

      scheduler_id = fn no -> schedulers |> Enum.at(no) |> Map.get(:id) end

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.get(http_client(ctx), "/projects/#{ctx.project_id}/tasks",
                 query: [page_token: scheduler_id.(5), page_size: 5]
               )

      assert Tesla.get_header(env, "per-page") == "5"
      assert Tesla.get_header(env, "previous-page-token") == scheduler_id.(4)
      assert Tesla.get_header(env, "next-page-token") == scheduler_id.(10)

      prefix_url = "<http://localhost:4004/api/#{api_version()}/projects/#{ctx.project_id}/tasks?"

      assert Tesla.get_header(env, "link")
             |> String.split(", ")
             |> Enum.map(&String.trim_leading(&1, prefix_url)) ==
               [
                 "direction=NEXT&page_size=5&page_token=#{scheduler_id.(10)}>; rel=\"next\"",
                 "direction=PREVIOUS&page_size=5&page_token=#{scheduler_id.(4)}>; rel=\"prev\"",
                 "direction=NEXT&page_size=5&page_token=>; rel=\"first\""
               ]

      assert Enum.count(env.body) == 5
    end

    test "GET /projects/:project_id_or_name/tasks/ - endpoint paginates backwards", ctx do
      schedulers =
        for i <- 1..14 do
          Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id,
            name: "Scheduler #{i |> Integer.to_string() |> String.pad_leading(2, "0")}"
          )
        end

      scheduler_id = fn no -> schedulers |> Enum.at(no) |> Map.get(:id) end

      assert {:ok, %Tesla.Env{status: 200} = env} =
               Tesla.get(http_client(ctx), "/projects/#{ctx.project_id}/tasks",
                 query: [page_token: scheduler_id.(3), page_size: 5, direction: "PREVIOUS"]
               )

      assert Tesla.get_header(env, "per-page") == "5"
      assert Tesla.get_header(env, "previous-page-token") == nil
      assert Tesla.get_header(env, "next-page-token") == scheduler_id.(4)

      prefix_url = "<http://localhost:4004/api/#{api_version()}/projects/#{ctx.project_id}/tasks?"

      assert Tesla.get_header(env, "link")
             |> String.split(", ")
             |> Enum.map(&String.trim_leading(&1, prefix_url)) ==
               [
                 "direction=NEXT&page_size=5&page_token=#{scheduler_id.(4)}>; rel=\"next\"",
                 "direction=NEXT&page_size=5&page_token=>; rel=\"first\""
               ]

      assert Enum.count(env.body) == 4
    end

    test "GET /projects/:project_id_or_name/tasks/ - task is not owned by requester org", ctx do
      for i <- 1..4 do
        Support.Stubs.Scheduler.create(ctx.project_id, ctx.user_id, name: "Scheduler #{i}")
      end

      GrpcMock.stub(SchedulerMock, :list_keyset, fn req, _opts ->
        alias Support.Stubs.DB

        periodics =
          DB.all(:schedulers)
          |> Enum.filter(fn o -> o.project_id == req.project_id end)
          |> Enum.map(fn %{api_model: api_model} -> %{api_model | project_id: UUID.uuid4()} end)

        %InternalApi.PeriodicScheduler.ListKeysetResponse{
          status: %InternalApi.Status{code: :OK},
          periodics: periodics
        }
      end)

      assert {:ok, %Tesla.Env{status: 404}} =
               Tesla.get(http_client(ctx), "/projects/#{ctx.project_id}/tasks")
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

  defp api_version(), do: System.get_env("API_VERSION")
end
