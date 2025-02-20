defmodule Router.ProjectSecrets.CreateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      Support.Stubs.Feature.enable_feature(org_id, "project_level_secrets")
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.view", project.id)
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.manage", project.id)

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project.id}}
    end

    test "create a secret", ctx do
      secret = construct_secret("some-test-secret")
      {:ok, response} = create_secret(ctx, secret)
      created_secret = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_secret)
      assert secret.spec.name == created_secret["metadata"]["name"]
    end

    test "without specified name in spec => fail", ctx do
      default_secret = construct_secret()

      secret =
        default_secret
        |> Map.put(:spec, Map.delete(default_secret.spec, :name))

      {:ok, response} = create_secret(ctx, secret)
      assert 422 == response.status_code
    end

    test "random version => fail", ctx do
      secret = construct_secret() |> Map.put(:apiVersion, "v3")
      {:ok, response} = create_secret(ctx, secret)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      secret = construct_secret() |> Map.put(:kind, "Secrets")
      {:ok, response} = create_secret(ctx, secret)

      assert 422 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      Support.Stubs.Feature.enable_feature(org_id, "project_level_secrets")
      #  permissions are not enough to create a secret, so user is unauthorized for the operation.
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.view", project.id)
      PermissionPatrol.add_permissions(org_id, user_id, "organization.secrets.manage")

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project.id}}
    end

    test "create a secret", ctx do
      secret = construct_secret()
      {:ok, response} = create_secret(ctx, secret)
      Jason.decode!(response.body)

      assert 404 == response.status_code

      spec = PublicAPI.ApiSpec.spec()
      assert_schema(response, "Error", spec)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "ProjectSecrets.Secret", spec)
  end

  defp construct_secret(name \\ "my-secret-1") do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.ProjectSecrets.Secret.schema())

    Map.put(default, :spec, Map.put(default.spec, :name, name))
  end

  defp create_secret(ctx, secret) do
    url = url() <> "/projects/#{ctx.project_id}/secrets?"

    body = Jason.encode!(secret)

    HTTPoison.post(url, body, headers(ctx))
  end
end
