defmodule Router.Projects.CreateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(org_id, user_id, "organization.projects.create")

      {:ok, %{org_id: org_id, user_id: user_id}}
    end

    test "create a project", ctx do
      project = construct_project()
      {:ok, response} = create_project(ctx, project)
      created_project = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_project)
    end

    test "create a project with sem-approve forked PR flags", ctx do
      project =
        construct_project()
        |> put_in(
          [:spec, :repository, :forked_pull_requests, :allow_sem_approve_include_secrets],
          true
        )
        |> put_in(
          [:spec, :repository, :forked_pull_requests, :allow_sem_approve_enable_cache],
          true
        )

      {:ok, response} = create_project(ctx, project)
      created_project = Jason.decode!(response.body)

      assert 200 == response.status_code

      assert get_in(created_project, [
               "spec",
               "repository",
               "forked_pull_requests",
               "allow_sem_approve_include_secrets"
             ]) == true

      assert get_in(created_project, [
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

      {:ok, response} = create_project(ctx, project)
      assert 422 == response.status_code
    end

    test "random version => fail", ctx do
      project = construct_project() |> Map.put(:apiVersion, "v3")
      {:ok, response} = create_project(ctx, project)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      project = construct_project() |> Map.put(:kind, "Secrets")
      {:ok, response} = create_project(ctx, project)

      assert 422 == response.status_code
    end

    test "pull_request_commit is sent to projecthub and returned", ctx do
      capture_create_requests()

      for value <- ~w(HEAD_COMMIT MERGE_COMMIT) do
        project =
          construct_project()
          |> update_repository(&Map.put(&1, :pull_request_commit, value))

        {:ok, response} = create_project(ctx, project)

        assert 200 == response.status_code
        assert_received {:create_request, req}
        assert req.project.spec.repository.pull_request_commit == String.to_atom(value)

        assert Jason.decode!(response.body)["spec"]["repository"]["pull_request_commit"] ==
                 value
      end
    end

    test "a create without pull_request_commit leaves the default to projecthub", ctx do
      capture_create_requests()

      project =
        construct_project()
        |> update_repository(&Map.delete(&1, :pull_request_commit))

      {:ok, response} = create_project(ctx, project)

      assert 200 == response.status_code
      assert_received {:create_request, req}
      assert req.project.spec.repository.pull_request_commit == :PULL_REQUEST_COMMIT_UNSPECIFIED

      assert Jason.decode!(response.body)["spec"]["repository"]["pull_request_commit"] ==
               "MERGE_COMMIT"
    end

    test "an unknown pull_request_commit is rejected before projecthub is called", ctx do
      capture_create_requests()

      for value <- ["head_commit", "PULL_REQUEST_COMMIT_UNSPECIFIED", "", nil] do
        project =
          construct_project()
          |> update_repository(&Map.put(&1, :pull_request_commit, value))

        {:ok, response} = create_project(ctx, project)

        assert 422 == response.status_code

        assert [%{"source" => %{"pointer" => "/spec/repository/pull_request_commit"}}] =
                 Jason.decode!(response.body)["errors"]
      end

      refute_received {:create_request, _}
    end

    test "a FAILED_PRECONDITION answer from projecthub is returned with its message", ctx do
      GrpcMock.stub(ProjecthubMock, :create, fn _req, _ ->
        alias InternalApi.Projecthub.ResponseMeta

        status = %ResponseMeta.Status{
          code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
          message: "head_commit is available only for GitHub projects"
        }

        %InternalApi.Projecthub.CreateResponse{metadata: %ResponseMeta{status: status}}
      end)

      on_exit(&Support.Stubs.Project.Grpc.Projecthub.init/0)

      project =
        construct_project()
        |> update_repository(
          &Map.merge(&1, %{integration_type: "BITBUCKET", pull_request_commit: "HEAD_COMMIT"})
        )

      {:ok, response} = create_project(ctx, project)

      assert 400 == response.status_code

      assert Jason.decode!(response.body) == %{
               "message" => "head_commit is available only for GitHub projects"
             }
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      #  permissions are not enough to create a project, so user is unauthorized for the operation.
      PermissionPatrol.add_permissions(org_id, user_id, "organization.secrets.manage")

      {:ok, %{org_id: org_id, user_id: user_id}}
    end

    test "create a project", ctx do
      project = construct_project()
      {:ok, response} = create_project(ctx, project)
      Jason.decode!(response.body)

      assert 404 == response.status_code

      spec = PublicAPI.ApiSpec.spec()
      assert_schema(response, "Error", spec)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Projects.Project", spec)
  end

  defp construct_project(name \\ "my-project") do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Projects.Project.schema())

    Map.put(default, :spec, Map.put(default.spec, :name, name))
  end

  defp update_repository(project, fun) do
    Map.update!(project, :spec, fn spec -> Map.update!(spec, :repository, fun) end)
  end

  defp capture_create_requests do
    test_pid = self()

    GrpcMock.stub(ProjecthubMock, :create, fn req, stream ->
      send(test_pid, {:create_request, req})
      Support.Stubs.Project.Grpc.Projecthub.create(req, stream)
    end)

    on_exit(&Support.Stubs.Project.Grpc.Projecthub.init/0)
  end

  defp create_project(ctx, project) do
    url = url() <> "/projects?"

    body = Jason.encode!(project)

    HTTPoison.post(url, body, headers(ctx))
  end
end
