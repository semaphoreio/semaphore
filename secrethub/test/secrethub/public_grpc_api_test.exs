defmodule Secrethub.PublicGrpcApi.Test do
  use Secrethub.DataCase
  alias Support.FakeServices

  alias Semaphore.Secrets.V1beta.{
    ListSecretsRequest,
    GetSecretRequest,
    DeleteSecretRequest,
    UpdateSecretRequest,
    SecretsApi,
    Secret,
    Empty
  }

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()

  @options [
    metadata: %{
      "x-semaphore-user-id" => @user_id,
      "x-semaphore-org-id" => @org_id
    },
    timeout: :infinity
  ]

  setup do
    FunRegistry.clear!()
    Cachex.clear(:auth_cache)
    Cachex.clear(:feature_cache)
    FakeServices.enable_features(["secrets_exposed_content"])

    :ok
  end

  describe ".list_secrets" do
    test "when the user is authorized to see secrets => it returns secrets" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)
      {:ok, s2} = Support.Factories.Secret.create("aws-2", @org_id)

      FakeServices.stub_auth_user()

      req = ListSecretsRequest.new()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert Enum.count(response.secrets) == 2
      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [s1.name, s2.name]
    end

    test "when the user is authorized to see secrets, but feature disables contents viewing=> it returns secrets without contents" do
      FakeServices.enable_features([])
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)
      {:ok, s2} = Support.Factories.Secret.create("aws-2", @org_id)

      FakeServices.stub_auth_user()

      req = ListSecretsRequest.new()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert Enum.count(response.secrets) == 2
      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [s1.name, s2.name]
      Enum.map(response.secrets, &assert_empty_content/1)
    end

    test "when the users is not authorized to see secrets => it returns error" do
      {:ok, _} = Support.Factories.Secret.create("aws-1", @org_id)
      {:ok, _} = Support.Factories.Secret.create("aws-2", @org_id)

      FakeServices.stub_unauth_user()

      req = ListSecretsRequest.new()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert response.message == "Can't list secrets in organization"
    end

    test "order by name" do
      {:ok, _} = Support.Factories.Secret.create("aws-C", @org_id)
      {:ok, _} = Support.Factories.Secret.create("aws-A", @org_id)
      {:ok, _} = Support.Factories.Secret.create("aws-B", @org_id)

      FakeServices.stub_auth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        ListSecretsRequest.new(
          page_size: 2,
          order: ListSecretsRequest.Order.value(:BY_NAME_ASC)
        )

      {:ok, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == ["aws-A", "aws-B"]

      req =
        ListSecretsRequest.new(
          page_size: 1,
          order: ListSecretsRequest.Order.value(:BY_NAME_ASC),
          page_token: response.next_page_token
        )

      {:ok, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == ["aws-C"]
      assert response.next_page_token == ""
    end

    test "order by create time" do
      {:ok, _} = Support.Factories.Secret.create("aws-C", @org_id)
      {:ok, _} = Support.Factories.Secret.create("aws-A", @org_id)
      {:ok, _} = Support.Factories.Secret.create("aws-B", @org_id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      FakeServices.stub_auth_user()

      req =
        ListSecretsRequest.new(
          page_size: 2,
          order: ListSecretsRequest.Order.value(:BY_CREATE_TIME_ASC)
        )

      {:ok, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == ["aws-C", "aws-A"]
      assert response.next_page_token != ""

      req =
        ListSecretsRequest.new(
          page_size: 2,
          order: ListSecretsRequest.Order.value(:BY_CREATE_TIME_ASC),
          page_token: response.next_page_token
        )

      {:ok, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == ["aws-B"]
      assert response.next_page_token == ""
    end

    test "when page_size is reasonable => limits the response" do
      {:ok, _} = Support.Factories.Secret.create("aws-C", @org_id)
      {:ok, _} = Support.Factories.Secret.create("aws-A", @org_id)
      {:ok, _} = Support.Factories.Secret.create("aws-B", @org_id)

      FakeServices.stub_auth_user()

      req =
        ListSecretsRequest.new(
          page_size: 2,
          order: ListSecretsRequest.Order.value(:BY_CREATE_TIME_ASC)
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == ["aws-C", "aws-A"]
    end

    test "when page_size is not reasonable => raises error" do
      req = ListSecretsRequest.new(page_size: 100_000)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.list_secrets(channel, req, @options)

      assert response.message == "Page size can't exceed 100"
    end
  end

  describe ".get_secret" do
    test "when the users is authorized to see secret and we are fetching by name => it returns secret" do
      {:ok, _} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_auth_user()

      req = GetSecretRequest.new(secret_id_or_name: "aws-1")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.get_secret(channel, req, @options)

      assert response.metadata.name == "aws-1"
      assert hd(response.data.env_vars).name == "aws_id"
      assert hd(response.data.env_vars).value == "21"
    end

    test "when the users is authorized to see secret and we are fetching by id => it returns secret" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_auth_user()

      req = GetSecretRequest.new(secret_id_or_name: s1.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.get_secret(channel, req, @options)

      assert response.metadata.name == "aws-1"
      assert hd(response.data.env_vars).name == "aws_id"
      assert hd(response.data.env_vars).value == "21"
    end

    test "when the users is authorized to see secret, content is restricted => it returns secret without contents" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.enable_features([])

      FakeServices.stub_auth_user()

      req = GetSecretRequest.new(secret_id_or_name: s1.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.get_secret(channel, req, @options)

      assert response.metadata.name == "aws-1"
      assert hd(response.data.env_vars).name == "aws_id"
      assert_empty_content(response)
    end

    test "when the users is not authorized to see secret and we are fetching by id => it returns error" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_unauth_user()

      req = GetSecretRequest.new(secret_id_or_name: s1.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.get_secret(channel, req, @options)

      assert response.message == "Secret #{s1.id} not found"
    end

    test "when the secret doesn't exists => it returns status not_found" do
      FakeServices.stub_auth_user()

      req = GetSecretRequest.new(secret_id_or_name: "aws-secrets")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.get_secret(channel, req, @options)

      assert response.message == "Secret aws-secrets not found"
    end

    test "when the secret has null values => it returns secret" do
      {:ok, _} =
        Support.Factories.Secret.insert("aws-1", @org_id,
          content: %{data: %{env_vars: [%{name: "aws_id", value: nil}]}}
        )

      FakeServices.stub_auth_user()

      req = GetSecretRequest.new(secret_id_or_name: "aws-1")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.get_secret(channel, req, @options)

      assert response.metadata.name == "aws-1"
      assert hd(response.data.env_vars).name == "aws_id"
      assert hd(response.data.env_vars).value == ""
    end
  end

  describe ".create_secret" do
    test "saves the secret to the store" do
      req = Support.Factories.PublicApi.secret("aws-1")

      FakeServices.stub_auth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.create_secret(channel, req, @options)

      {:ok, secret} = Secrethub.Secret.find_by_name(@org_id, "aws-1")

      assert response.metadata.name == secret.name
      assert response.metadata.id == secret.id
      assert response.data == req.data
    end

    test "returns secret without contents" do
      req = Support.Factories.PublicApi.secret("aws-1")
      FakeServices.enable_features([])
      FakeServices.stub_auth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.create_secret(channel, req, @options)

      {:ok, secret} = Secrethub.Secret.find_by_name(@org_id, "aws-1")

      assert response.metadata.name == secret.name
      assert response.metadata.id == secret.id
      assert_empty_content(response)
    end

    test "raises error if the name is not unique" do
      req1 = Support.Factories.PublicApi.secret("aws-1")
      req2 = Support.Factories.PublicApi.secret("aws-1")

      FakeServices.stub_auth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      assert {:ok, _} = SecretsApi.Stub.create_secret(channel, req1, @options)

      {:error, error} = SecretsApi.Stub.create_secret(channel, req2, @options)

      assert %GRPC.RPCError{message: "name has already been taken", status: 3} = error
    end

    test "raises error if the name is in uuid format" do
      req = Support.Factories.PublicApi.secret(Ecto.UUID.generate())

      FakeServices.stub_auth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, error} = SecretsApi.Stub.create_secret(channel, req, @options)

      assert %GRPC.RPCError{message: "name should not be in uuid format", status: 3} = error
    end

    test "raises error if the name is not alphanumeric" do
      req = Support.Factories.PublicApi.secret("aaaa/s/s/s/a")

      FakeServices.stub_auth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, error} = SecretsApi.Stub.create_secret(channel, req, @options)

      assert %GRPC.RPCError{
               message:
                 "name can only include alpha-numeric characters, dashes, underscores and dots",
               status: 3
             } = error
    end

    test "unathorized" do
      req = Support.Factories.PublicApi.secret("test")

      FakeServices.stub_unauth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, error} = SecretsApi.Stub.create_secret(channel, req, @options)

      assert %GRPC.RPCError{message: "You are not authorized to create secrets", status: 7} =
               error
    end

    test "when there are empty values => raises error" do
      req =
        Semaphore.Secrets.V1beta.Secret.new(
          metadata: Secret.Metadata.new(name: "aws-1"),
          data:
            Secret.Data.new(
              env_vars: [
                Secret.EnvVar.new(name: "A", value: "")
              ],
              files: [
                Secret.File.new(path: "asd", content: "xyz")
              ]
            )
        )

      FakeServices.stub_auth_user()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, %GRPC.RPCError{message: message, status: status}} =
        SecretsApi.Stub.create_secret(channel, req, @options)

      assert status == 3
      assert message =~ "value can't be blank"
    end

    test "when secrets_access_policy features are enabled & user has permissions => save user input" do
      req =
        Support.Factories.PublicApi.with_org_options(Support.Factories.PublicApi.secret("aws-1"))

      FakeServices.stub_auth_user()

      FakeServices.enable_features([
        "secrets_exposed_content",
        "secrets_access_policy",
        "project_level_secrets"
      ])

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.create_secret(channel, req, @options)

      {:ok, secret} = Secrethub.Secret.find_by_name(@org_id, "aws-1")

      assert response.metadata.name == secret.name
      assert response.metadata.id == secret.id
      assert response.data == req.data
      assert response.org_config == req.org_config
      FakeServices.enable_features([])
    end

    test "when features are enabled & user does not have permissions => save default org_config" do
      req =
        Support.Factories.PublicApi.with_org_options(Support.Factories.PublicApi.secret("aws-1"))

      FakeServices.stub_auth_user(["organization.secrets.manage"])

      FakeServices.enable_features([
        "secrets_exposed_content",
        "secrets_access_policy",
        "project_level_secrets"
      ])

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.create_secret(channel, req, @options)

      {:ok, secret} = Secrethub.Secret.find_by_name(@org_id, "aws-1")

      assert response.metadata.name == secret.name
      assert response.metadata.id == secret.id
      assert response.data == req.data
      assert response.org_config == Semaphore.Secrets.V1beta.Secret.OrgConfig.new()
      FakeServices.enable_features([])
    end
  end

  describe ".update_secret" do
    test "when the secret is found => updates the secret" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_auth_user()

      req =
        UpdateSecretRequest.new(
          secret_id_or_name: s1.name,
          secret:
            Secret.new(
              metadata: Secret.Metadata.new(name: "new-name"),
              data:
                Secret.Data.new(
                  env_vars: [
                    Secret.EnvVar.new(name: "A", value: "B")
                  ]
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.update_secret(channel, req, @options)

      {:ok, secret} = Secrethub.Secret.find_by_name(@org_id, req.secret.metadata.name)

      assert secret.name == "new-name"
      assert length(secret.content.env_vars) == length(req.secret.data.env_vars)
      assert length(secret.content.env_vars) == length(req.secret.data.env_vars)
      assert response.org_config == nil
    end

    test "doesn't raise error if the old name is non alphanumric" do
      #
      # This allows updating old secrets in the database, that are not following the new rules.
      #

      {:ok, secret} = Support.Factories.Secret.insert("a/b/c/d", @org_id)
      FakeServices.stub_auth_user()

      req =
        UpdateSecretRequest.new(
          secret_id_or_name: secret.name,
          secret:
            Secret.new(
              metadata: Secret.Metadata.new(name: "a/b/c/d"),
              data: Secret.Data.new(env_vars: [])
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, _} = SecretsApi.Stub.update_secret(channel, req, @options)
    end

    test "when the secret is not found => returns not found" do
      FakeServices.stub_auth_user()

      req =
        UpdateSecretRequest.new(
          secret_id_or_name: "AAA",
          secret:
            Secret.new(
              metadata: Secret.Metadata.new(name: "AAA"),
              data:
                Secret.Data.new(
                  env_vars: [
                    Secret.EnvVar.new(name: "A", value: "B")
                  ]
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.update_secret(channel, req, @options)

      assert response.message == "Secret AAA not found"
    end

    test "when not authorized to change secret => returns not_found" do
      {:ok, _} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_unauth_user()

      req =
        UpdateSecretRequest.new(
          secret_id_or_name: "aws-1",
          secret:
            Secret.new(
              metadata: Secret.Metadata.new(name: "AAA"),
              data:
                Secret.Data.new(
                  env_vars: [
                    Secret.EnvVar.new(name: "A", value: "B")
                  ]
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.update_secret(channel, req, @options)

      assert response.message == "Secret aws-1 not found"
    end

    test "features enabled & access enabled => updates the secret" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_auth_user()

      FakeServices.enable_features([
        "secrets_exposed_content",
        "secrets_access_policy",
        "project_level_secrets"
      ])

      req =
        UpdateSecretRequest.new(
          secret_id_or_name: s1.name,
          secret:
            Secret.new(
              metadata: Secret.Metadata.new(name: "new-name"),
              data:
                Secret.Data.new(
                  env_vars: [
                    Secret.EnvVar.new(name: "A", value: "B")
                  ]
                ),
              org_config:
                Secret.OrgConfig.new(
                  projects_access: :ALLOWED,
                  projects_ids: ["project-1", "project-2"],
                  debug_access: :JOB_DEBUG_YES,
                  attach_access: :JOB_ATTACH_YES
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, _} = SecretsApi.Stub.update_secret(channel, req, @options)

      {:ok, secret} = Secrethub.Secret.find_by_name(@org_id, req.secret.metadata.name)

      assert secret.name == "new-name"
      assert length(secret.content.env_vars) == length(req.secret.data.env_vars)
      assert secret.all_projects == false
      assert secret.project_ids == req.secret.org_config.project_ids
      assert secret.job_debug == Secret.OrgConfig.JobDebugAccess.value(:JOB_DEBUG_YES)
      assert secret.job_attach == Secret.OrgConfig.JobAttachAccess.value(:JOB_ATTACH_YES)
    end

    test "features enabled & user can not edit permissions => updates the secret but not permissions" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_auth_user(["organization.secrets.manage"])

      FakeServices.enable_features([
        "secrets_exposed_content",
        "secrets_access_policy",
        "project_level_secrets"
      ])

      req =
        UpdateSecretRequest.new(
          secret_id_or_name: s1.name,
          secret:
            Secret.new(
              metadata: Secret.Metadata.new(name: "new-name"),
              data:
                Secret.Data.new(
                  env_vars: [
                    Secret.EnvVar.new(name: "A", value: "B")
                  ]
                ),
              org_config:
                Secret.OrgConfig.new(
                  projects_access: :ALLOWED,
                  projects_ids: ["project-1", "project-2"],
                  debug_access: :JOB_DEBUG_YES,
                  attach_access: :JOB_ATTACH_YES
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, _} = SecretsApi.Stub.update_secret(channel, req, @options)

      {:ok, secret} = Secrethub.Secret.find_by_name(@org_id, req.secret.metadata.name)

      assert secret.name == "new-name"
      assert length(secret.content.env_vars) == length(req.secret.data.env_vars)
      assert secret.all_projects == s1.all_projects
      assert secret.project_ids == s1.project_ids
      assert secret.job_debug == s1.job_debug
      assert secret.job_attach == s1.job_attach
    end

    test "secrets contents are hidden => updates are rejected" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)
      FakeServices.stub_auth_user([:ManageSecrets])
      FakeServices.enable_features([])

      req =
        UpdateSecretRequest.new(
          secret_id_or_name: s1.name,
          secret:
            Secret.new(
              metadata: Secret.Metadata.new(name: "new-name"),
              data:
                Secret.Data.new(
                  env_vars: [
                    Secret.EnvVar.new(name: "A", value: "B")
                  ]
                ),
              org_config:
                Secret.OrgConfig.new(
                  projects_access: :ALLOWED,
                  projects_ids: ["project-1", "project-2"],
                  debug_access: :JOB_DEBUG_YES,
                  attach_access: :JOB_ATTACH_YES
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.update_secret(channel, req, @options)

      assert "Secret can not be updated with API" == response.message
    end
  end

  describe ".delete_secret" do
    test "deletes existing secrets and returns empty response" do
      {:ok, _} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_auth_user()

      assert {:ok, _} = Secrethub.Secret.find_by_name(@org_id, "aws-1")

      req = DeleteSecretRequest.new(secret_id_or_name: "aws-1")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretsApi.Stub.delete_secret(channel, req, @options)

      assert response == Empty.new()
      assert {:error, :not_found} = Secrethub.Secret.find_by_name(@org_id, "aws-1")
    end

    test "when secret doens't exists => it returns not found" do
      FakeServices.stub_auth_user()

      req = DeleteSecretRequest.new(secret_id_or_name: "aws-1")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.delete_secret(channel, req, @options)

      assert response.message == "Secret aws-1 not found"
    end

    test "raise error if try to deletes existing secret without access" do
      {:ok, _} = Support.Factories.Secret.create("aws-1", @org_id)

      FakeServices.stub_unauth_user()

      assert {:ok, _} = Secrethub.Secret.find_by_name(@org_id, "aws-1")

      req = DeleteSecretRequest.new(secret_id_or_name: "aws-1")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, response} = SecretsApi.Stub.delete_secret(channel, req, @options)

      assert response.message == "Secret aws-1 not found"
      assert {:ok, _} = Secrethub.Secret.find_by_name(@org_id, "aws-1")
    end
  end

  test ".serialize" do
    {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

    secret = Secrethub.PublicGrpcApi.serialize(s1, "")

    assert secret.metadata.name == s1.name
    assert secret.metadata.id == s1.id
    refute is_nil(secret.metadata.create_time)
    refute is_nil(secret.metadata.update_time)
  end

  defp assert_empty_content(secret) do
    assert Enum.all?(secret.data.env_vars, &(&1.value == ""))
    assert Enum.all?(secret.data.files, &(&1.content == ""))
  end
end
