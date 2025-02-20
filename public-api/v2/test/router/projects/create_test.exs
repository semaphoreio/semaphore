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

  defp create_project(ctx, project) do
    url = url() <> "/projects?"

    body = Jason.encode!(project)

    HTTPoison.post(url, body, headers(ctx))
  end
end
