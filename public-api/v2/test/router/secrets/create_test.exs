defmodule Router.Secrets.CreateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users with secrets_access_policy feature" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      Support.Stubs.Feature.enable_feature(org_id, "secrets_access_policy")
      PermissionPatrol.add_permissions(org_id, user_id, "organization.secrets.manage")

      PermissionPatrol.add_permissions(
        org_id,
        user_id,
        "organization.secrets_policy_settings.manage"
      )

      {:ok, %{org_id: org_id, user_id: user_id}}
    end

    test "create a secret", ctx do
      secret = construct_secret("a-secret-named-one")
      {:ok, response} = create_secret(ctx, secret)
      created_secret = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_secret)
      assert secret.spec.name == created_secret["metadata"]["name"]
    end

    test "when secrets_access_policy opts set => add it to request", ctx do
      default_secret = construct_secret("b-secret")

      acces_config = %{
        project_access: %{
          project_ids: [UUID.uuid4()],
          project_access: "ALLOWED"
        }
      }

      secret =
        default_secret
        |> Map.put(
          :spec,
          Map.merge(default_secret.spec, %{access_config: acces_config})
        )

      GrpcMock.stub(SecretMock, :create, fn req, _ ->
        alias InternalApi.Secrethub.ResponseMeta

        assert req.secret.org_config.project_access.project_ids ==
                 acces_config.project_access.project_ids

        assert req.secret.org_config.project_access.project_access == acces_config.project_access
        assert req.secret.org_config.debug_access == :JOB_DEBUG_YES
        assert req.secret.org_config.attach_access == :JOB_ATTACH_YES

        %InternalApi.Secrethub.CreateResponse{
          secret: secret,
          metadata: %ResponseMeta{
            status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
          }
        }
      end)

      {:ok, _response} = create_secret(ctx, secret)

      # cleanup
      Support.Stubs.Secret.Grpc.init()
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

  describe "authorized users without secrets_access_policy feature" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(org_id, user_id, "organization.secrets.manage")

      {:ok, %{org_id: org_id, user_id: user_id}}
    end

    test "create a secret", ctx do
      secret = construct_secret("some-name-1")
      {:ok, response} = create_secret(ctx, secret)
      created_secret = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_secret)
      assert secret.spec.name == created_secret["metadata"]["name"]
    end

    test "when secrets_access_policy opts set => use defaults", ctx do
      default_secret = construct_secret()

      acces_config = %{
        project_access: %{
          project_ids: [UUID.uuid4()],
          project_access: "ALLOWED"
        }
      }

      secret =
        default_secret
        |> Map.put(
          :spec,
          Map.merge(default_secret.spec, %{access_config: acces_config})
        )

      GrpcMock.stub(SecretMock, :create, fn req, _ ->
        config = req.secret.org_config
        alias InternalApi.Secrethub.ResponseMeta
        refute config.project_access.project_ids == acces_config.project_access.project_ids
        refute config.project_access.project_access == acces_config.project_access
        assert config.debug_access == :JOB_DEBUG_YES
        assert config.attach_access == :JOB_ATTACH_YES
        assert config.project_access.project_ids == []
        assert config.project_access.project_access == :ALL

        %InternalApi.Secrethub.CreateResponse{
          secret: secret,
          metadata: %ResponseMeta{
            status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
          }
        }
      end)

      {:ok, _response} = create_secret(ctx, secret)

      # cleanup
      Support.Stubs.Secret.Grpc.init()
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Secrets.Secret", spec)
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

  defp create_secret(ctx, secret) do
    url = url() <> "/secrets"

    body = Jason.encode!(secret)

    HTTPoison.post(url, body, headers(ctx))
  end
end
