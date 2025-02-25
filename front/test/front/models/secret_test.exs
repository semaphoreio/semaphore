defmodule Front.Models.SecretTest do
  use ExUnit.Case
  alias Front.Models.Secret
  alias Support.Stubs.{DB, PermissionPatrol}

  alias InternalApi.Secrethub

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)

    PermissionPatrol.allow_everything(organization.id, user.id)

    secret = DB.first(:secrets)

    params = %{
      env_vars: [
        %{"name" => "AWS", "value" => "123"},
        %{"name" => "GCLOUD", "value" => "456"}
      ],
      files: [
        %{"content" => "aaa", "path" => "/var/lib/"},
        %{"content" => "bbb", "path" => "/tmp/"}
      ]
    }

    env_vars = [
      %{"name" => "AWS", "value" => "123", "md5" => "hhh"},
      %{"name" => "GCLOUD", "value" => "", "md5" => "hhh"},
      %{"name" => "HEROKU", "value" => "", "md5" => ""},
      %{"name" => "SOMETHING_ELSE", "value" => "789", "md5" => ""},
      %{"name" => "YO", "value" => "", "md5" => ""},
      %{"name" => "", "value" => "13", "md5" => ""},
      %{"name" => "", "value" => "", "md5" => ""}
    ]

    files = [
      %{"content" => "aaa", "path" => "/var/lib/", "md5" => "hhh"},
      %{"content" => "", "path" => "/tmp/", "md5" => "hhh"},
      %{"content" => "", "path" => "some_path", "md5" => ""},
      %{"content" => "ccc", "path" => "lib", "md5" => ""},
      %{"content" => "", "path" => "path", "md5" => ""},
      %{"content" => "ddd", "path" => "", "md5" => ""},
      %{"content" => "", "path" => "", "md5" => ""}
    ]

    org_config = %{
      projects_access: :ALL,
      project_ids: []
    }

    [
      secret: secret,
      user: user,
      organization: organization,
      params: params,
      org_config: org_config,
      env_vars: env_vars,
      files: files
    ]
  end

  describe ".list" do
    test "when the response is succesfull => returns a list of secrets", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      secrets = Secret.list(user.id, organization.id)

      assert Enum.count(secrets) == 1
      s = List.first(secrets)

      assert s.name == secret.name
      assert s.id == secret.id
    end

    test "when the response is an permission denied => returns an error response", %{
      user: user,
      organization: org
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org.id, user.id, "organization.secrets.view")

      [] = Secret.list(user.id, org.id)
    end

    test "when the response is an error => returns an empty list", %{
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :list_keyset, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      secrets = Secret.list(user.id, organization.id)
      assert Enum.empty?(secrets)
    end

    test "when the response is an metadata error => returns an empty list", %{
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :list_keyset, fn _, _ ->
        %{
          metadata: %{
            status: %{code: :FAILED_PRECONDITION, message: "Some metadata error"}
          }
        }
        |> Util.Proto.deep_new!(Secrethub.ListKeysetResponse)
      end)

      secrets = Secret.list(user.id, organization.id)
      assert Enum.empty?(secrets)
    end
  end

  describe ".find" do
    test "when the response is succesfull => returns a full secret", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      {:ok, s} = Secret.find(secret.id, user.id, organization.id)

      assert s.id == secret.id
    end

    test "when fetching project level secrets withouth project_id", %{
      user: user,
      organization: org,
      secret: secret
    } do
      {:error, :permission_denied} =
        Secret.find(secret.id, user.id, org.id, secret_level: :PROJECT)
    end

    test "when the response is an permission denied => returns an error response", %{
      user: user,
      organization: org,
      secret: secret
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org.id, user.id, "organization.secrets.view")

      {:error, :permission_denied} = Secret.find(secret.id, user.id, org.id)
    end

    test "when the response is GRPC error => returns the error", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :describe, fn _, _ ->
        raise GRPC.RPCError, status: 5, message: "Not found"
      end)

      {:error, :not_found} = Secret.find(secret.id, user.id, organization.id)
    end

    test "when the response is metadata error => returns the error", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :describe, fn _, _ ->
        %{
          metadata: %{
            status: %{code: :NOT_FOUND, message: "Secret not found"}
          }
        }
        |> Util.Proto.deep_new!(Secrethub.DescribeResponse)
      end)

      {:error, :not_found} = Secret.find(secret.id, user.id, organization.id)
    end
  end

  describe ".create" do
    test "when the response is succesfull => returns an ok response", %{
      user: user,
      organization: organization,
      org_config: org_config,
      params: params
    } do
      {:ok, _} =
        Secret.create("Name", params, org_config, :ORGANIZATION, user.id, organization.id)
    end

    test "when the response is an permission denied => returns an error response", %{
      user: user,
      organization: org,
      org_config: org_config,
      params: params
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org.id, user.id, "organization.secrets.manage")

      {:error, :permission_denied} =
        Secret.create("Name", params, org_config, :ORGANIZATION, user.id, org.id)

      Cachex.clear!(:auth_cache)
      Cachex.clear!(:feature_provider_cache)
    end

    test "when the response is an error => returns an error response", %{
      user: user,
      organization: organization,
      params: params
    } do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      {:error, %{errors: %{other: "Unknown"}}} =
        Secret.create("Name", params, nil, :ORGANIZATION, user.id, organization.id)
    end

    test "when the response is an invalid argument error => returns an error response", %{
      user: user,
      organization: organization,
      params: params
    } do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Invalid"
      end)

      {:error, %{errors: %{other: "Invalid"}}} =
        Secret.create("Name", params, nil, :ORGANIZATION, user.id, organization.id)
    end

    test "when the response is an meta error => returns an error response", %{
      user: user,
      organization: organization,
      params: params
    } do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        %{
          metadata: %{
            status: %{code: :FAILED_PRECONDITION, message: "Invalid arguments"}
          }
        }
        |> Util.Proto.deep_new!(Secrethub.CreateResponse)
      end)

      {:error, %{errors: %{other: "Invalid arguments"}}} =
        Secret.create("Name", params, nil, :ORGANIZATION, user.id, organization.id)
    end
  end

  describe ".update" do
    test "when missing certain types -> updates correctly", %{
      user: user,
      organization: organization,
      secret: secret,
      env_vars: env_vars
    } do
      description = secret.api_model.metadata.description
      files = []

      {:ok, _} =
        Secret.update(
          secret.id,
          secret.name,
          description,
          env_vars,
          files,
          user.id,
          organization.id
        )
    end

    test "when the response is succesfull => returns an ok response", %{
      user: user,
      organization: organization,
      org_config: org_config,
      secret: secret
    } do
      description = secret.api_model.metadata.description
      env_vars = []
      files = []

      {:ok, _} =
        Secret.update(
          secret.id,
          secret.name,
          description,
          env_vars,
          files,
          user.id,
          organization.id,
          org_config: org_config
        )
    end

    test "when user does not have permissions => returns an error response", %{
      secret: secret,
      user: user,
      org_config: org_config,
      organization: org
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org.id, user.id, "organization.secrets.manage")

      description = secret.api_model.metadata.description
      env_vars = []
      files = []

      {:error, :permission_denied} =
        Secret.update(
          secret.id,
          secret.name,
          description,
          env_vars,
          files,
          user.id,
          org.id,
          org_config: org_config
        )
    end

    test "when the response is a GRPC not found error => returns an error response", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :update, fn _, _ ->
        raise GRPC.RPCError, status: 5, message: "Not found"
      end)

      description = secret.api_model.metadata.description
      env_vars = []
      files = []

      {:error, :not_found} =
        Secret.update(
          secret.id,
          secret.name,
          description,
          env_vars,
          files,
          user.id,
          organization.id
        )
    end

    test "when the response is a metadata not found error => returns an error response", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :update, fn _, _ ->
        %{
          metadata: %{
            status: %{code: :NOT_FOUND, message: "Not found"}
          }
        }
        |> Util.Proto.deep_new!(Secrethub.UpdateResponse)
      end)

      description = secret.api_model.metadata.description
      env_vars = []
      files = []

      {:error, :not_found} =
        Secret.update(
          secret.id,
          secret.name,
          description,
          env_vars,
          files,
          user.id,
          organization.id
        )
    end

    test "when the response is an invalid arg error => returns an error response", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :update, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Invalid"
      end)

      description = secret.api_model.metadata.description
      env_vars = []
      files = []

      {:error, "Failed: Invalid"} =
        Secret.update(
          secret.id,
          secret.name,
          description,
          env_vars,
          files,
          user.id,
          organization.id
        )
    end

    test "when the response is an invalid arg metadata error => returns an error response", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :update, fn _, _ ->
        %{
          metadata: %{
            status: %{code: :FAILED_PRECONDITION, message: "Invalid"}
          }
        }
        |> Util.Proto.deep_new!(Secrethub.UpdateResponse)
      end)

      description = secret.api_model.metadata.description
      env_vars = []
      files = []

      assert {:error, %{errors: %{other: "Invalid"}}} ==
               Secret.update(
                 secret.id,
                 secret.name,
                 description,
                 env_vars,
                 files,
                 user.id,
                 organization.id
               )
    end
  end

  describe ".destroy" do
    test "when the response is succesfull => returns an ok response", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      {:ok, _} = Secret.destroy(secret.id, user.id, organization.id)
    end

    test "when user does not have permissions => returns an error response", %{
      secret: secret,
      user: user,
      organization: org
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org.id, user.id, "organization.secrets.manage")

      {:error, :permission_denied} = Secret.destroy(secret.id, user.id, org.id)
    end

    test "when the response is an error => returns an error response", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :destroy, fn _, _ ->
        raise GRPC.RPCError, status: 5, message: "Not found"
      end)

      {:error, :not_found} = Secret.destroy(secret.id, user.id, organization.id)
    end

    test "when the response is an metadata error => returns an error response", %{
      secret: secret,
      user: user,
      organization: organization
    } do
      GrpcMock.stub(SecretMock, :destroy, fn _, _ ->
        %{
          metadata: %{
            status: %{code: :NOT_FOUND, message: "Not found"}
          }
        }
        |> Util.Proto.deep_new!(Secrethub.UpdateResponse)
      end)

      {:error, :not_found} = Secret.destroy(secret.id, user.id, organization.id)
    end
  end
end
