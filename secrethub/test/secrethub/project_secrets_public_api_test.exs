defmodule Secrethub.ProjectSecretsPublicApi.Test do
  use Secrethub.DataCase
  @moduletag capture_log: true

  alias Semaphore.ProjectSecrets.V1, as: API
  alias Semaphore.ProjectSecrets.V1.ProjectSecretsApi.Stub, as: APIStub

  use Support.PrepareFunctions, API
  alias Support.FakeServices

  alias Semaphore.ProjectSecrets.V1.{
    ListSecretsRequest,
    GetSecretRequest,
    DeleteSecretRequest,
    UpdateSecretRequest,
    Secret
  }

  setup do
    FunRegistry.clear!()
    Cachex.clear(:auth_cache)
    FakeServices.enable_features(["secrets_exposed_content"])
    Cachex.clear(:feature_cache)

    :ok
  end

  describe ".list_secrets" do
    setup [
      :prepare_data,
      :prepare_secret,
      :stub_projects
    ]

    test "when feature is not enabled => it returns an error", ctx do
      FakeServices.stub_auth_user()
      FakeServices.enable_features([])

      assert {:error,
              %GRPC.RPCError{
                message: "Project level secrets are not enabled for this organization"
              }} = APIStub.list_secrets(chan(), ListSecretsRequest.new(), options(ctx))
    end

    test "feature enabled, user unauthorized => it returns an error", ctx do
      FakeServices.stub_unauth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      assert {:error, %GRPC.RPCError{message: "User is not authorized to perform this operation"}} =
               APIStub.list_secrets(
                 chan(),
                 ListSecretsRequest.new(project_id_or_name: ctx.project_id),
                 options(ctx)
               )
    end

    test "secrets exist => returns secrets", ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      assert {:ok,
              %API.ListSecretsResponse{
                secrets: [
                  %API.Secret{
                    metadata: %API.Secret.Metadata{
                      project_id_or_name: ^project_id
                    }
                  }
                ]
              }} =
               APIStub.list_secrets(
                 chan(),
                 ListSecretsRequest.new(project_id_or_name: project_id, page_size: 10),
                 options(ctx)
               )
    end

    test "secrets exist, query by project name => returns secrets",
         ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      assert {:ok,
              %API.ListSecretsResponse{
                secrets: [
                  %API.Secret{
                    metadata: %API.Secret.Metadata{
                      project_id_or_name: ^project_id
                    }
                  }
                ]
              }} =
               APIStub.list_secrets(
                 chan(),
                 ListSecretsRequest.new(project_id_or_name: ctx.project_name, page_size: 10),
                 options(ctx)
               )
    end

    test "secrets exist, contents hidden => returns secrets", ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["project_level_secrets"])

      assert {:ok,
              %API.ListSecretsResponse{
                secrets: [
                  %API.Secret{
                    metadata: %API.Secret.Metadata{
                      project_id_or_name: ^project_id,
                      content_included: false
                    },
                    data: %API.Secret.Data{
                      env_vars: [
                        %Semaphore.ProjectSecrets.V1.Secret.EnvVar{name: "VAR1", value: ""},
                        %Semaphore.ProjectSecrets.V1.Secret.EnvVar{name: "VAR2", value: ""}
                      ]
                    }
                  }
                ]
              }} =
               APIStub.list_secrets(
                 chan(),
                 ListSecretsRequest.new(project_id_or_name: project_id, page_size: 10),
                 options(ctx)
               )
    end
  end

  describe ".get_secret" do
    setup [
      :prepare_data,
      :prepare_secret,
      :stub_projects
    ]

    test "when feature is not enabled => it returns an error", ctx do
      FakeServices.stub_auth_user()
      FakeServices.enable_features([])

      assert {:error,
              %GRPC.RPCError{
                message: "Project level secrets are not enabled for this organization"
              }} = APIStub.get_secret(chan(), GetSecretRequest.new(), options(ctx))
    end

    test "feature enabled, user unauthorized => it returns an error", ctx do
      FakeServices.stub_unauth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      assert {:error, %GRPC.RPCError{message: "User is not authorized to perform this operation"}} =
               APIStub.get_secret(
                 chan(),
                 GetSecretRequest.new(project_id_or_name: ctx.project_id),
                 options(ctx)
               )
    end

    test "secret exists, user enabled, feature enabled, lookup by name => returns the secret",
         ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features()

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id
                }
              }} =
               APIStub.get_secret(
                 chan(),
                 GetSecretRequest.new(
                   project_id_or_name: ctx.project_id,
                   secret_id_or_name: ctx.secret.name
                 ),
                 options(ctx)
               )
    end

    test "secret exists, user enabled, feature enabled, lookup by id => returns the secret",
         ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features()

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id
                }
              }} =
               APIStub.get_secret(
                 chan(),
                 GetSecretRequest.new(
                   project_id_or_name: ctx.project_id,
                   secret_id_or_name: ctx.secret.id
                 ),
                 options(ctx)
               )
    end

    test "secrets exist, query by project name => returns secrets",
         ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features()

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id
                }
              }} =
               APIStub.get_secret(
                 chan(),
                 GetSecretRequest.new(
                   project_id_or_name: ctx.project_name,
                   secret_id_or_name: ctx.secret.id
                 ),
                 options(ctx)
               )
    end

    test "secret exists, user enabled, feature enabled, lookup by name, hide content => returns the secret",
         ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["project_level_secrets"])

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id,
                  content_included: false
                },
                data: %API.Secret.Data{
                  env_vars: [
                    %API.Secret.EnvVar{name: "VAR1", value: ""},
                    %API.Secret.EnvVar{name: "VAR2", value: ""}
                  ]
                }
              }} =
               APIStub.get_secret(
                 chan(),
                 GetSecretRequest.new(
                   project_id_or_name: ctx.project_id,
                   secret_id_or_name: ctx.secret.name
                 ),
                 options(ctx)
               )
    end
  end

  describe ".create_secret" do
    setup [
      :prepare_data,
      :prepare_params,
      :stub_projects
    ]

    test "when feature is not enabled => it returns an error", ctx do
      FakeServices.stub_auth_user()
      FakeServices.enable_features([])

      assert {:error,
              %GRPC.RPCError{
                message: "Project level secrets are not enabled for this organization"
              }} = APIStub.create_secret(chan(), Secret.new(), options(ctx))
    end

    test "feature enabled, user unauthorized => it returns an error", ctx do
      FakeServices.stub_unauth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      assert {:error, %GRPC.RPCError{message: "User is not authorized to perform this operation"}} =
               APIStub.create_secret(chan(), Secret.new(), options(ctx))
    end

    test "feature enabled, user authorized, provide project name => creates the secret",
         ctx = %{project_id: project_id, raw_data: raw_data} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      secret = %{
        ctx.params
        | data: ctx.raw_data,
          metadata: %{ctx.params.metadata | project_id_or_name: ctx.project_name}
      }

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id
                },
                data: ^raw_data
              }} =
               APIStub.create_secret(
                 chan(),
                 secret,
                 options(ctx)
               )
    end

    test "feature enabled, user authorized, provide project name, without content => creates the secret without content",
         ctx = %{project_id: project_id} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["project_level_secrets"])

      secret = %{
        ctx.params
        | data: ctx.raw_data,
          metadata: %{ctx.params.metadata | project_id_or_name: ctx.project_name}
      }

      return_data = %{
        ctx.raw_data
        | env_vars:
            Enum.map(ctx.raw_data.env_vars, fn e ->
              %API.Secret.EnvVar{name: e.name, value: ""}
            end),
          files:
            Enum.map(ctx.raw_data.files, fn f -> %API.Secret.File{path: f.path, content: ""} end)
      }

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id,
                  content_included: false
                },
                data: ^return_data
              }} =
               APIStub.create_secret(
                 chan(),
                 secret,
                 options(ctx)
               )
    end
  end

  describe ".update_secret" do
    setup [
      :prepare_data,
      :prepare_secret,
      :prepare_params,
      :stub_projects
    ]

    test "when feature is not enabled => it returns an error", ctx do
      FakeServices.stub_auth_user()
      FakeServices.enable_features([])

      assert {:error,
              %GRPC.RPCError{
                message: "Project level secrets are not enabled for this organization"
              }} = APIStub.update_secret(chan(), UpdateSecretRequest.new(), options(ctx))
    end

    test "feature enabled, user unauthorized => it returns an error", ctx do
      FakeServices.stub_unauth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      assert {:error, %GRPC.RPCError{message: "User is not authorized to perform this operation"}} =
               APIStub.update_secret(
                 chan(),
                 UpdateSecretRequest.new(project_id_or_name: ctx.project_id),
                 options(ctx)
               )
    end

    test "feature enabled, user authorized, secret exists => updates the secret",
         ctx = %{project_id: project_id, raw_data: raw_data} do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["secrets_exposed_content", "project_level_secrets"])

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id
                },
                data: ^raw_data
              }} =
               APIStub.update_secret(
                 chan(),
                 UpdateSecretRequest.new(
                   secret: %{ctx.params | data: ctx.raw_data},
                   project_id_or_name: ctx.project_id,
                   secret_id_or_name: ctx.secret.id
                 ),
                 options(ctx)
               )
    end

    test "feature enabled, user authorized, secret exists, identify with project_name => updates the secret",
         ctx = %{project_id: project_id, raw_data: raw_data} do
      FakeServices.stub_auth_user()

      FakeServices.enable_features([
        "secrets_exposed_content",
        "project_level_secrets"
      ])

      assert {:ok,
              %API.Secret{
                metadata: %API.Secret.Metadata{
                  project_id_or_name: ^project_id
                },
                data: ^raw_data
              }} =
               APIStub.update_secret(
                 chan(),
                 UpdateSecretRequest.new(
                   secret: %{ctx.params | data: ctx.raw_data},
                   project_id_or_name: ctx.project_name,
                   secret_id_or_name: ctx.secret.id
                 ),
                 options(ctx)
               )
    end

    test "feature enabled, user authorized, secret exists, contents hidden => rejects update",
         ctx do
      FakeServices.stub_auth_user()
      FakeServices.enable_features(["project_level_secrets"])

      assert {:error,
              %GRPC.RPCError{
                message: "Secret can not be updated with API"
              }} =
               APIStub.update_secret(
                 chan(),
                 UpdateSecretRequest.new(
                   secret: %{ctx.params | data: ctx.raw_data},
                   project_id_or_name: ctx.project_id,
                   secret_id_or_name: ctx.secret.id
                 ),
                 options(ctx)
               )
    end
  end

  describe ".delete_secret" do
    setup [
      :prepare_data,
      :prepare_secret
    ]

    test "when feature is not enabled => it returns an error", ctx do
      FakeServices.stub_auth_user()
      FakeServices.enable_features([])

      assert {:error,
              %GRPC.RPCError{
                message: "Project level secrets are not enabled for this organization"
              }} = APIStub.delete_secret(chan(), DeleteSecretRequest.new(), options(ctx))
    end

    test "feature enabled, user unauthorized => it returns an error", ctx do
      FakeServices.stub_unauth_user()

      FakeServices.enable_features([
        "secrets_exposed_content",
        "project_level_secrets"
      ])

      assert {:error, %GRPC.RPCError{message: "User is not authorized to perform this operation"}} =
               APIStub.delete_secret(
                 chan(),
                 DeleteSecretRequest.new(project_id_or_name: ctx.project_id),
                 options(ctx)
               )
    end

    test "existing secret, feature enabled, user authorized => it deletes the secret", ctx do
      FakeServices.stub_auth_user()

      FakeServices.enable_features([
        "secrets_exposed_content",
        "project_level_secrets"
      ])

      assert {:ok, %API.Empty{}} =
               APIStub.delete_secret(
                 chan(),
                 DeleteSecretRequest.new(
                   project_id_or_name: ctx.project_id,
                   secret_id_or_name: ctx.secret.id
                 ),
                 options(ctx)
               )
    end
  end

  defp chan do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    channel
  end

  defp options(ctx) do
    [
      metadata: %{
        "x-semaphore-user-id" => ctx.user_id,
        "x-semaphore-org-id" => ctx.org_id
      },
      timeout: :infinity
    ]
  end

  defp stub_projects(ctx) do
    project_name = FakeServices.stub_projects(ctx.project_id)
    {:ok, project_name: project_name}
  end
end
