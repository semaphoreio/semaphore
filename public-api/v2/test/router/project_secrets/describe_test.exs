defmodule Router.ProjectSecrets.DescribeTest do
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

      Support.Stubs.Feature.enable_feature(org_id, "project_level_secrets")
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.view", project_id)

      secret =
        Support.Stubs.Secret.create("secret1", %{level: :PROJECT, project_id: project_id},
          org_id: org_id,
          user_id: user_id
        )

      {:ok,
       %{
         org_id: org_id,
         user_id: user_id,
         secret: secret,
         project_id: project_id,
         project: project
       }}
    end

    test "describe a secret by id", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a secret by name", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a not existant secret", ctx do
      {:ok, response} = get_secret(ctx, "not_existant")
      assert 404 == response.status_code
    end

    test "describe a secret not owned by the requester org", ctx do
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

      {:ok, response} = get_secret(ctx, secret.id)
      assert 404 == response.status_code
    end

    test "describe secret with with project name as context", ctx do
      ctx = ctx |> Map.put(:project_id, ctx.project.name)
      {:ok, response} = get_secret(ctx, ctx.secret.name)
      assert 200 == response.status_code
      check_response(response)
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      secret =
        Support.Stubs.Secret.create("secret1", %{level: :ORGANIZATION, project_id: ""},
          org_id: org_id,
          user_id: user_id
        )

      {:ok, %{org_id: org_id, user_id: user_id, secret: secret, project_id: project_id}}
    end

    test "describe a secret by id", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.id)
      assert 404 == response.status_code
    end

    test "describe a secret by name", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.name)
      assert 404 == response.status_code
    end

    test "describe a not existant secret", ctx do
      {:ok, response} = get_secret(ctx, "not_existant")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "ProjectSecrets.Secret", spec)
  end

  defp get_secret(ctx, id_or_name) do
    url = url() <> "/projects/#{ctx.project_id}/secrets/#{id_or_name}"

    HTTPoison.get(url, headers(ctx))
  end
end
