defmodule Router.Projects.DeleteTest do
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

      PermissionPatrol.add_permissions(org_id, user_id, "project.delete", project_id)

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id, project: project}}
    end

    test "delete a project by id", ctx do
      {:ok, response} = delete_project(ctx, ctx.project.id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "delete a project by name", ctx do
      {:ok, response} = delete_project(ctx, ctx.project.name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "delete a not existant project", ctx do
      {:ok, response} = delete_project(ctx, "doesn-t-exist")
      assert 404 == response.status_code
    end

    test "delete a project not owned by the requester org", ctx do
      org_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: ctx.user_id}, id: UUID.uuid4())

      GrpcMock.stub(ProjecthubMock, :describe, fn _req, _ ->
        alias InternalApi.Projecthub.ResponseMeta
        status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
        meta = %ResponseMeta{status: status}
        require Logger
        %InternalApi.Projecthub.DescribeResponse{metadata: meta, project: project.api_model}
      end)

      {:ok, response} = delete_project(ctx, ctx.project_id)
      assert 404 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      # this is not enough to delete a project, so user is unauthorized for the operation.
      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project_id)

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id, project: project}}
    end

    test "delete a project by id", ctx do
      {:ok, response} = delete_project(ctx, ctx.project.id)
      assert 404 == response.status_code
    end

    test "delete a project by name", ctx do
      {:ok, response} = delete_project(ctx, ctx.project.name)
      assert 404 == response.status_code
    end

    test "delete a not existant project", ctx do
      {:ok, response} = delete_project(ctx, "not_existant")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Projects.DeleteResponse", spec)
  end

  defp delete_project(ctx, id_or_name) do
    url = url() <> "/projects/#{id_or_name}"

    HTTPoison.delete(url, headers(ctx))
  end
end
