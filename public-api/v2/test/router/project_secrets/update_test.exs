defmodule Router.ProjectSecrets.UpdateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      Support.Stubs.Feature.enable_feature(org_id, "project_level_secrets")
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.view", project_id)
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.manage", project_id)

      secret =
        Support.Stubs.Secret.create("secret1", %{level: :PROJECT, project_id: project_id},
          org_id: org_id,
          user_id: user_id
        )

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id, secret: secret}}
    end

    test "update a secret", ctx do
      secret = construct_secret("a-secret")
      {:ok, response} = update_secret(ctx, ctx.secret.id, secret)
      updated_secret = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(response)
      assert secret.spec.name == updated_secret["metadata"]["name"]
    end

    test "without specified name in spec => fail", ctx do
      default_secret = construct_secret()

      secret =
        default_secret
        |> Map.put(:spec, Map.delete(default_secret.spec, :name))

      {:ok, response} = update_secret(ctx, ctx.secret.id, secret)
      assert 422 == response.status_code
    end

    test "random version => fail", ctx do
      secret = construct_secret() |> Map.put(:apiVersion, "v3")
      {:ok, response} = update_secret(ctx, ctx.secret.id, secret)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      secret = construct_secret() |> Map.put(:kind, "Secrets")
      {:ok, response} = update_secret(ctx, ctx.secret.id, secret)

      assert 422 == response.status_code
    end

    test "update a secret not owned by the requester org", ctx do
      secret =
        Support.Stubs.Secret.create("secret1", %{
          level: :PROJECT,
          org_id: UUID.uuid4(),
          project_id: ctx.project_id
        })

      GrpcMock.stub(SecretMock, :describe, fn _req, _ ->
        alias Support.Stubs.DB
        alias InternalApi.Secrethub.ResponseMeta
        secret = DB.find_by(:secrets, :id, secret.id)

        %InternalApi.Secrethub.DescribeResponse{
          secret: secret.api_model,
          metadata: %ResponseMeta{
            status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
          }
        }
      end)

      secret = construct_secret()

      {:ok, response} = update_secret(ctx, ctx.secret.id, secret)
      assert 404 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      Support.Stubs.Feature.enable_feature(org_id, "project_level_secrets")
      #  permissions are not enough to modify a secret, so user is unauthorized for the operation.
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.view", project_id)
      PermissionPatrol.add_permissions(org_id, user_id, "organization.secrets.manage")

      secret =
        Support.Stubs.Secret.create("secret1", %{level: :PROJECT, project_id: project_id},
          org_id: org_id,
          user_id: user_id
        )

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id, secret: secret}}
    end

    test "update a secret", ctx do
      secret = construct_secret()
      {:ok, response} = update_secret(ctx, ctx.secret.id, secret)
      Jason.decode!(response.body)

      assert 404 == response.status_code

      spec = PublicAPI.ApiSpec.spec()
      assert_schema(response, "Error", spec)
    end
  end

  defp construct_secret(name \\ "my-secret-1") do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Secrets.Secret.schema())
    env_vars = [OpenApiSpex.Schema.example(PublicAPI.Schemas.Secrets.Secret.EnvVar.schema())]
    files = [OpenApiSpex.Schema.example(PublicAPI.Schemas.Secrets.Secret.File.schema())]

    data = %{
      env_vars: env_vars,
      files: files
    }

    spec =
      Map.put(default.spec, :name, name)
      |> Map.put(:data, data)

    Map.put(default, :spec, spec)
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "ProjectSecrets.Secret", spec)
  end

  defp update_secret(ctx, id_or_name, secret) do
    url = url() <> "/projects/#{ctx.project_id}/secrets/#{id_or_name}"
    body = Jason.encode!(secret)

    HTTPoison.put(url, body, headers(ctx))
  end
end
