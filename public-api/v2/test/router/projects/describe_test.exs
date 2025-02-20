defmodule Router.Projects.DescribeTest do
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

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project_id)

      {:ok,
       %{org_id: org_id, user_id: user_id, project_id: project_id, project_name: project.name}}
    end

    test "describe a project by id", ctx do
      {:ok, response} = get_project(ctx, ctx.project_id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a project by name", ctx do
      {:ok, response} = get_project(ctx, ctx.project_name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a not existant project", ctx do
      {:ok, response} = get_project(ctx, "not_existant")
      assert 404 == response.status_code
    end

    test "describe a project not owned by the requester org", ctx do
      org_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: ctx.user_id}, id: UUID.uuid4())

      GrpcMock.stub(ProjecthubMock, :describe, fn _req, _ ->
        alias InternalApi.Projecthub.ResponseMeta
        status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
        meta = %ResponseMeta{status: status}

        %InternalApi.Projecthub.DescribeResponse{metadata: meta, project: project.api_model}
      end)

      {:ok, response} = get_project(ctx, ctx.project_id)
      assert 404 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      {:ok,
       %{org_id: org_id, user_id: user_id, project_id: project_id, project_name: project.name}}
    end

    test "describe a project by id", ctx do
      {:ok, response} = get_project(ctx, ctx.project_id)
      assert 404 == response.status_code
    end

    test "describe a project by name", ctx do
      {:ok, response} = get_project(ctx, ctx.project_name)
      assert 404 == response.status_code
    end

    test "describe a not existant project", ctx do
      {:ok, response} = get_project(ctx, "not_existant")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Projects.Project", spec)
  end

  defp get_project(ctx, id_or_name) do
    url = url() <> "/projects/#{id_or_name}"

    HTTPoison.get(url, headers(ctx))
  end
end
