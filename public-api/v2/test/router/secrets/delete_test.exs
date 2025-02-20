defmodule Router.Secrets.DeleteTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(org_id, user_id, "organization.secrets.manage")

      secret =
        Support.Stubs.Secret.create("secret1", %{level: :ORGANIZATION, project_id: ""},
          org_id: org_id,
          user_id: user_id
        )

      {:ok, %{org_id: org_id, user_id: user_id, secret: secret}}
    end

    test "delete a secret by id", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "delete a secret by name", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "delete a not existant secret", ctx do
      {:ok, response} = get_secret(ctx, "not_existant")
      assert 404 == response.status_code
    end

    test "delete a secret not owned by the user's organization -> 404", ctx do
      secret =
        Support.Stubs.Secret.create(
          "other-org-secret-for-tests",
          %{level: :ORGANIZATION, org_id: UUID.uuid4(), project_id: ""}
        )

      {:ok, response} = get_secret(ctx, ctx.secret.id)
      assert 200 == response.status_code

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

      {:ok, response} = get_secret(ctx, ctx.secret.id)
      assert 404 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      secret =
        Support.Stubs.Secret.create("secret1", %{level: :ORGANIZATION, project_id: ""},
          org_id: org_id,
          user_id: user_id
        )

      {:ok, %{org_id: org_id, user_id: user_id, secret: secret}}
    end

    test "delete a secret by id", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.id)
      assert 404 == response.status_code
    end

    test "delete a secret by name", ctx do
      {:ok, response} = get_secret(ctx, ctx.secret.name)
      assert 404 == response.status_code
    end

    test "delete a not existant secret", ctx do
      {:ok, response} = get_secret(ctx, "not_existant")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Secrets.DeleteResponse", spec)
  end

  defp get_secret(ctx, id_or_name) do
    url = url() <> "/secrets/#{id_or_name}"

    HTTPoison.delete(url, headers(ctx))
  end
end
