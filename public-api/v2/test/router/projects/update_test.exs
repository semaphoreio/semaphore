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
