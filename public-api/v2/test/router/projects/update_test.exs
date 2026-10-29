defmodule Router.Projects.UpdateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(
        org_id,
        user_id,
        "project.repository_info.manage",
        project_id
      )

      PermissionPatrol.add_permissions(
        org_id,
        user_id,
        "project.general_settings.manage",
        project_id
      )

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id, project: project}}
    end

    test "update a project", ctx do
      project = construct_project("a-project")

      {:ok, response} = update_project(ctx, ctx.project.id, project)
      updated_project = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(response)
      assert project.spec.name == updated_project["metadata"]["name"]
    end

    test "a project that builds draft pull requests round-trips", ctx do
      test_pid = self()
      project_id = UUID.uuid4()

      Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id},
        id: project_id,
        run_on: ["branches", "draft_pull_requests"]
      )

      for permission <- [
            "project.view",
            "project.repository_info.manage",
            "project.general_settings.manage"
          ] do
        PermissionPatrol.add_permissions(ctx.org_id, ctx.user_id, permission, project_id)
      end

      GrpcMock.stub(ProjecthubMock, :update, fn req, stream ->
        send(test_pid, {:update_request, req})
        Support.Stubs.Project.Grpc.Projecthub.update(req, stream)
      end)

      on_exit(&Support.Stubs.Project.Grpc.Projecthub.init/0)

      {:ok, response} = HTTPoison.get(url() <> "/projects/#{project_id}", headers(ctx))

      assert 200 == response.status_code
      run_on = Jason.decode!(response.body)["spec"]["repository"]["run_on"]
      assert run_on == ["BRANCHES", "DRAFT_PULL_REQUESTS"]

      project =
        Map.update!(construct_project("a-project"), :spec, fn spec ->
          Map.update!(spec, :repository, &Map.put(&1, :run_on, run_on))
        end)

      {:ok, response} = update_project(ctx, project_id, project)

      assert 200 == response.status_code
      assert_received {:update_request, req}
      assert req.project.spec.repository.run_on == [:BRANCHES, :DRAFT_PULL_REQUESTS]
      assert Jason.decode!(response.body)["spec"]["repository"]["run_on"] == run_on
    end

    test "update a project with sem-approve forked PR flags", ctx do
      project =
        construct_project("a-project")
        |> put_in(
          [:spec, :repository, :forked_pull_requests, :allow_sem_approve_include_secrets],
          true
        )
        |> put_in(
          [:spec, :repository, :forked_pull_requests, :allow_sem_approve_enable_cache],
          true
        )

      {:ok, response} = update_project(ctx, ctx.project.id, project)
      updated_project = Jason.decode!(response.body)

      assert 200 == response.status_code

      assert get_in(updated_project, [
               "spec",
               "repository",
               "forked_pull_requests",
               "allow_sem_approve_include_secrets"
             ]) == true

      assert get_in(updated_project, [
               "spec",
               "repository",
               "forked_pull_requests",
               "allow_sem_approve_enable_cache"
             ]) == true
    end

    test "without specified name in spec => fail", ctx do
      default_project = construct_project()

      project =
        default_project
        |> Map.put(:spec, Map.delete(default_project.spec, :name))

      {:ok, response} = update_project(ctx, ctx.project.id, project)
      assert 422 == response.status_code
    end

    test "random version => fail", ctx do
      project = construct_project() |> Map.put(:apiVersion, "v3")
      {:ok, response} = update_project(ctx, ctx.project.id, project)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      project = construct_project() |> Map.put(:kind, "ProjectS")
      {:ok, response} = update_project(ctx, ctx.project.id, project)

      assert 422 == response.status_code
    end

    test "update a project not owned by the requester org", ctx do
      org_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: ctx.user_id}, id: UUID.uuid4())

      GrpcMock.stub(ProjecthubMock, :describe, fn _req, _ ->
        alias InternalApi.Projecthub.ResponseMeta
        status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
        meta = %ResponseMeta{status: status}
        require Logger
        %InternalApi.Projecthub.DescribeResponse{metadata: meta, project: project.api_model}
      end)

      update_project = construct_project()

      {:ok, response} = update_project(ctx, ctx.project_id, update_project)
      assert 404 == response.status_code
    end

    test "an update without pull_request_commit sends UNSPECIFIED, which keeps the stored value",
         ctx do
      capture_update_requests()

      project =
        construct_project("a-project")
        |> update_repository(&Map.delete(&1, :pull_request_commit))

      {:ok, response} = update_project(ctx, ctx.project.id, project)

      assert 200 == response.status_code
      assert_received {:update_request, req}
      assert req.project.spec.repository.pull_request_commit == :PULL_REQUEST_COMMIT_UNSPECIFIED
    end

    test "pull_request_commit is sent to projecthub and returned", ctx do
      capture_update_requests()

      for value <- ~w(HEAD_COMMIT MERGE_COMMIT) do
        project =
          construct_project("a-project")
          |> update_repository(&Map.put(&1, :pull_request_commit, value))

        {:ok, response} = update_project(ctx, ctx.project.id, project)

        assert 200 == response.status_code
        check_response(response)
        assert_received {:update_request, req}
        assert req.project.spec.repository.pull_request_commit == String.to_atom(value)

        assert Jason.decode!(response.body)["spec"]["repository"]["pull_request_commit"] ==
                 value
      end
    end

    test "an unknown pull_request_commit is rejected before projecthub is called", ctx do
      capture_update_requests()

      for value <- ["head_commit", "PULL_REQUEST_COMMIT_UNSPECIFIED", "", nil] do
        project =
          construct_project("a-project")
          |> update_repository(&Map.put(&1, :pull_request_commit, value))

        {:ok, response} = update_project(ctx, ctx.project.id, project)

        assert 422 == response.status_code

        assert [%{"source" => %{"pointer" => "/spec/repository/pull_request_commit"}}] =
                 Jason.decode!(response.body)["errors"]
      end

      refute_received {:update_request, _}
    end

    test "a FAILED_PRECONDITION answer from projecthub is returned with its message", ctx do
      GrpcMock.stub(ProjecthubMock, :update, fn _req, _ ->
        alias InternalApi.Projecthub.ResponseMeta

        status = %ResponseMeta.Status{
          code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
          message: "head_commit is available only for GitHub projects"
        }

        %InternalApi.Projecthub.UpdateResponse{metadata: %ResponseMeta{status: status}}
      end)

      on_exit(&Support.Stubs.Project.Grpc.Projecthub.init/0)

      project =
        construct_project("a-project")
        |> update_repository(&Map.put(&1, :pull_request_commit, "HEAD_COMMIT"))

      {:ok, response} = update_project(ctx, ctx.project.id, project)

      assert 400 == response.status_code

      assert Jason.decode!(response.body) == %{
               "message" => "head_commit is available only for GitHub projects"
             }
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      #  permissions are not enough to modify a project, so user is unauthorized for the operation.
      PermissionPatrol.add_permissions(
        org_id,
        user_id,
        "project.general_settings.manage",
        project_id
      )

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id, project: project}}
    end

    test "update a project", ctx do
      project = construct_project()
      {:ok, response} = update_project(ctx, ctx.project.id, project)
      _updated_project = Jason.decode!(response.body)

      assert 404 == response.status_code

      spec = PublicAPI.ApiSpec.spec()
      assert_schema(response, "Error", spec)
    end
  end

  defp construct_project(name \\ "my-project-1") do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Projects.Project.schema())

    Map.put(default, :spec, Map.put(default.spec, :name, name))
  end

  defp update_repository(project, fun) do
    Map.update!(project, :spec, fn spec -> Map.update!(spec, :repository, fun) end)
  end

  defp capture_update_requests do
    test_pid = self()

    GrpcMock.stub(ProjecthubMock, :update, fn req, stream ->
      send(test_pid, {:update_request, req})
      Support.Stubs.Project.Grpc.Projecthub.update(req, stream)
    end)

    on_exit(&Support.Stubs.Project.Grpc.Projecthub.init/0)
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Projects.Project", spec)
  end

  defp update_project(ctx, id_or_name, project) do
    url = url() <> "/projects/#{id_or_name}"
    body = Jason.encode!(project)

    HTTPoison.put(url, body, headers(ctx))
  end
end
