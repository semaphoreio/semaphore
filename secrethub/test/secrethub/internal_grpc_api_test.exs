defmodule Secrethub.InternalGrpcApi.Test do
  use ExUnit.Case
  use Secrethub.DataCase
  import Mock

  alias InternalApi.Secrethub.{
    DescribeManyRequest,
    DescribeRequest,
    DestroyRequest,
    GenerateOpenIDConnectTokenRequest,
    ListRequest,
    ListKeysetRequest,
    CheckoutManyRequest,
    CheckoutMetadata,
    Secret,
    SecretService,
    UpdateJWTConfigRequest,
    GetJWTConfigRequest,
    ClaimConfig
  }

  @org_id Ecto.UUID.generate()

  def req_meta, do: req_meta(@org_id)

  def req_meta(org_id) do
    InternalApi.Secrethub.RequestMeta.new(
      api_version: "v1alpha",
      kind: "Secret",
      org_id: org_id,
      req_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate()
    )
  end

  describe ".list" do
    test "it returns list of secrets" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)
      {:ok, s2} = Support.Factories.Secret.create("aws-2", @org_id)

      req = ListRequest.new(metadata: req_meta(s1.org_id))

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.list(channel, req)

      assert Enum.count(response.secrets) == 2
      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [s1.name, s2.name]
    end

    test "it returns a list of secrets allowed for use in one project" do
      {:ok, s1, allowed1} = Support.Factories.Secret.with_project("aws-1", @org_id)
      allowed2 = [Ecto.UUID.generate()]

      {:ok, _s2, _allowed2} =
        Support.Factories.Secret.with_project("aws-2", s1.org_id, false, allowed2)

      {:ok, s3} = Support.Factories.Secret.create("aws-3", @org_id)
      {:ok, _s4, _} = Support.Factories.Secret.with_project("aws-4", s1.org_id, false, [])

      [project_id | _] = allowed1
      req = ListRequest.new(metadata: req_meta(s1.org_id), project_id: project_id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.list(channel, req)

      assert Enum.count(response.secrets) == 2
      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [s1.name, s3.name]
    end
  end

  describe ".list_keyset" do
    test "it returns only list of secrets, no contents" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)
      {:ok, s2} = Support.Factories.Secret.create("aws-2", @org_id)

      req = ListKeysetRequest.new(metadata: req_meta(s1.org_id), ignore_contents: true)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.list_keyset(channel, req)

      assert Enum.count(response.secrets) == 2
      assert Enum.any?(response.secrets, fn _ -> s1.name end)
      assert Enum.any?(response.secrets, fn _ -> s2.name end)
      assert Enum.all?(response.secrets, fn s -> s.data == nil end)
    end

    test "it returns list of secrets with contents" do
      {:ok, s1} = Support.Factories.Secret.create("aws-3", @org_id)
      {:ok, s2} = Support.Factories.Secret.create("aws-4", @org_id)

      req = ListKeysetRequest.new(metadata: req_meta(s1.org_id))

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.list_keyset(channel, req)

      assert Enum.count(response.secrets) == 2
      assert Enum.any?(response.secrets, fn _ -> s1.name end)
      assert Enum.any?(response.secrets, fn _ -> s2.name end)
      assert Enum.all?(response.secrets, fn s -> s.data != nil end)
    end
  end

  describe ".describe" do
    test "when the secret exists => it returns status ok" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      req = DescribeRequest.new(metadata: req_meta(s1.org_id), name: s1.name)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe(channel, req)

      assert response.secret.metadata.name == s1.name
      assert hd(response.secret.data.env_vars).name == "aws_id"
      assert hd(response.secret.data.env_vars).value == "21"
      assert response.secret.org_config.debug_access == :JOB_DEBUG_NO
      assert response.secret.org_config.attach_access == :JOB_ATTACH_YES
    end

    test "when the secret exists (lookup by id) => it returns status ok" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      req = DescribeRequest.new(metadata: req_meta(s1.org_id), id: s1.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe(channel, req)

      assert response.secret.metadata.name == s1.name
      assert hd(response.secret.data.env_vars).name == "aws_id"
      assert hd(response.secret.data.env_vars).value == "21"
      assert response.secret.org_config.debug_access == :JOB_DEBUG_NO
      assert response.secret.org_config.attach_access == :JOB_ATTACH_YES
    end

    test "when the secret doesn't exists => it returns status not_found" do
      req = DescribeRequest.new(metadata: req_meta(), name: "aws-secrets")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe(channel, req)

      assert response.metadata.status.code == :NOT_FOUND
    end

    test "allowed for none if allow list sent is empty" do
      {:ok, s1, _} = Support.Factories.Secret.with_project("aws-1", req_meta().org_id, false, [])

      req = DescribeRequest.new(metadata: req_meta(), id: s1.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe(channel, req)

      assert response.secret.metadata.name == s1.name
      assert response.secret.org_config.projects_access == :NONE
      assert response.secret.org_config.project_ids == []
    end

    test "allowed list saved" do
      {:ok, s1, allowed} = Support.Factories.Secret.with_project("aws-1", @org_id)

      req = DescribeRequest.new(metadata: req_meta(s1.org_id), id: s1.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe(channel, req)

      assert response.secret.metadata.name == s1.name
      assert response.secret.org_config.projects_access == :ALLOWED
      assert response.secret.org_config.project_ids == allowed
    end

    test "default allowed for all" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      req = DescribeRequest.new(metadata: req_meta(s1.org_id), id: s1.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe(channel, req)

      assert response.secret.metadata.name == s1.name
      assert response.secret.org_config.projects_access == :ALL
      assert response.secret.org_config.project_ids == []
    end
  end

  describe ".describe_many" do
    test "ids in the request => it returns the secrets that exists in the db" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)
      {:ok, s2} = Support.Factories.Secret.create("aws-2", @org_id)

      random_id = Ecto.UUID.generate()
      req = DescribeManyRequest.new(metadata: req_meta(), ids: [s1.id, s2.id, random_id])

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe_many(channel, req)

      assert Enum.count(response.secrets) == 2
      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [s1.name, s2.name]
      assert Enum.map(response.secrets, fn s -> s.metadata.id end) == [s1.id, s2.id]
    end

    test "names in the request => it returns the secrets in the same order as requested" do
      meta = req_meta()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])
      {:ok, s2} = Support.Factories.Secret.create("aws-2", meta.org_id, [], [])

      random_name = "borg"

      req =
        DescribeManyRequest.new(
          metadata: meta,
          names: [s1.name, s2.name, random_name, s1.name]
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe_many(channel, req)

      assert Enum.count(response.secrets) == 3

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [
               s1.name,
               s2.name,
               s1.name
             ]
    end

    test "names with DT secret in request => it returns DT secrets first" do
      meta = req_meta()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])

      {:ok, dts} =
        Secrethub.DeploymentTargets.Store.create(%{
          name: "DT123456",
          dt_id: Ecto.UUID.generate(),
          org_id: meta.org_id,
          content: %{env_vars: [], files: []},
          created_by: Ecto.UUID.generate(),
          updated_by: Ecto.UUID.generate()
        })

      random_name = "borg"

      req =
        DescribeManyRequest.new(
          metadata: meta,
          names: [s1.name, dts.name, random_name, s1.name, dts.name]
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe_many(channel, req)

      assert Enum.count(response.secrets) == 3

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [
               dts.name,
               s1.name,
               s1.name
             ]
    end

    test "empty request => empty response" do
      meta = req_meta()

      req = DescribeManyRequest.new(metadata: meta, ids: [], names: [])

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe_many(channel, req)

      assert response.secrets == []
    end
  end

  describe ".checkout_many" do
    test "names with DT secret in request => it returns DT secrets first" do
      meta = req_meta()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])

      {:ok, dts} =
        Secrethub.DeploymentTargets.Store.create(%{
          name: "DT123456",
          dt_id: Ecto.UUID.generate(),
          org_id: meta.org_id,
          content: %{env_vars: [], files: []},
          created_by: Ecto.UUID.generate(),
          updated_by: Ecto.UUID.generate()
        })

      random_name = "borg"

      req =
        CheckoutManyRequest.new(
          metadata: meta,
          names: [s1.name, dts.name, random_name, s1.name, dts.name],
          project_id: Ecto.UUID.generate(),
          checkout_metadata: CheckoutMetadata.new(job_id: Ecto.UUID.generate())
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.checkout_many(channel, req)

      assert Enum.count(response.secrets) == 3

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [
               dts.name,
               s1.name,
               s1.name
             ]
    end

    test "names of project level secret in request => it returns project level secrets" do
      meta = req_meta()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])

      {:ok, ps} =
        Secrethub.ProjectSecrets.Store.create(%{
          name: "Project",
          project_id: Ecto.UUID.generate(),
          org_id: meta.org_id,
          content: %{env_vars: [], files: []},
          created_by: Ecto.UUID.generate(),
          updated_by: Ecto.UUID.generate()
        })

      random_name = "borg"

      req =
        CheckoutManyRequest.new(
          metadata: meta,
          names: [s1.name, ps.name, random_name, s1.name, ps.name],
          project_id: ps.project_id,
          checkout_metadata: CheckoutMetadata.new(job_id: Ecto.UUID.generate())
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.checkout_many(channel, req)

      assert Enum.count(response.secrets) == 3

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [
               ps.name,
               s1.name,
               s1.name
             ]
    end

    test "name of project secret and org secret match => project level secret overwrites org secret" do
      meta = req_meta()
      project_id = Ecto.UUID.generate()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])
      {:ok, s2} = Support.Factories.Secret.create("org-secret-1", meta.org_id, [], [])

      {:ok, ps1} =
        Secrethub.ProjectSecrets.Store.create(%{
          name: "aws-1",
          project_id: project_id,
          org_id: meta.org_id,
          content: %{env_vars: [], files: []},
          created_by: Ecto.UUID.generate(),
          updated_by: Ecto.UUID.generate()
        })

      {:ok, ps2} =
        Secrethub.ProjectSecrets.Store.create(%{
          name: "aws-2",
          project_id: project_id,
          org_id: meta.org_id,
          content: %{env_vars: [], files: []},
          created_by: Ecto.UUID.generate(),
          updated_by: Ecto.UUID.generate()
        })

      random_name = "borg"

      req =
        CheckoutManyRequest.new(
          metadata: meta,
          names: [ps1.name, random_name, s1.name, ps2.name, s2.name],
          project_id: project_id,
          checkout_metadata: CheckoutMetadata.new(job_id: Ecto.UUID.generate())
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.checkout_many(channel, req)

      assert Enum.count(response.secrets) == 3

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [
               ps1.name,
               ps2.name,
               s2.name
             ]

      # to make sure that aws-1 secret is the project level secret (ps1 and not s1)
      assert Enum.map(response.secrets, fn s -> s.metadata.created_by end) == [
               ps1.created_by,
               ps2.created_by,
               s2.created_by
             ]
    end

    test "names in request, project with access=> it returns the secrets in the same order as requested" do
      meta = req_meta()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])

      {:ok, s2, project_ids} = Support.Factories.Secret.with_project("aws-2", meta.org_id, false)

      random_name = "borg"

      req =
        CheckoutManyRequest.new(
          metadata: meta,
          names: [s1.name, s2.name, random_name, s1.name],
          project_id: hd(project_ids),
          checkout_metadata: CheckoutMetadata.new(job_id: Ecto.UUID.generate())
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.checkout_many(channel, req)

      assert Enum.count(response.secrets) == 3

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [
               s1.name,
               s2.name,
               s1.name
             ]
    end

    test "names in request, project without access=> it returns only allowed secrets" do
      meta = req_meta()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])
      {:ok, s2, _project_ids} = Support.Factories.Secret.with_project("aws-2", meta.org_id)

      random_name = "borg"

      req =
        CheckoutManyRequest.new(
          metadata: meta,
          names: [s1.name, s2.name, random_name, s1.name],
          project_id: Ecto.UUID.generate(),
          checkout_metadata: CheckoutMetadata.new(job_id: Ecto.UUID.generate())
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.checkout_many(channel, req)

      assert Enum.count(response.secrets) == 2

      assert Enum.map(response.secrets, fn s -> s.metadata.name end) == [
               s1.name,
               s1.name
             ]
    end

    test "request without checkout_metadata => failed precondition" do
      meta = req_meta()

      {:ok, s1} = Support.Factories.Secret.create("aws-1", meta.org_id, [], [])
      {:ok, s2, _project_ids} = Support.Factories.Secret.with_project("aws-2", meta.org_id)

      random_name = "borg"

      req =
        CheckoutManyRequest.new(
          metadata: meta,
          names: [s1.name, s2.name, random_name, s1.name],
          project_id: Ecto.UUID.generate()
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.checkout_many(channel, req)

      assert Enum.empty?(response.secrets)

      assert response.metadata.status.code == :FAILED_PRECONDITION
    end

    test "empty request => empty response" do
      meta = req_meta()

      req = DescribeManyRequest.new(metadata: meta, ids: [], names: [])

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.describe_many(channel, req)

      assert response.secrets == []
    end
  end

  describe ".create" do
    test "saves the secret to the store" do
      req_metadata = req_meta()

      req =
        InternalApi.Secrethub.CreateRequest.new(
          metadata: req_metadata,
          secret: Support.Factories.InternalApi.secret("aws-secrets")
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.create(channel, req)

      assert response.metadata.status.code == :OK

      {:ok, secret} = Secrethub.Secret.find(req_metadata.org_id, response.secret.metadata.id)

      assert response.secret.metadata.name == secret.name
      assert response.secret.metadata.id == secret.id
      assert response.secret.data.env_vars == req.secret.data.env_vars
      assert response.secret.data.files == req.secret.data.files
    end

    test "when the name is not unique => it raises an error" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        InternalApi.Secrethub.CreateRequest.new(
          metadata: req_meta(),
          secret: Support.Factories.InternalApi.secret("aws-secrets")
        )

      {:ok, response1} = SecretService.Stub.create(channel, req)
      {:ok, response2} = SecretService.Stub.create(channel, req)

      assert response1.metadata.status.code == :OK

      assert response2.metadata.status.code == :FAILED_PRECONDITION
    end

    test "with empty fields => it raises an error" do
      req_metadata = req_meta()

      req =
        InternalApi.Secrethub.CreateRequest.new(
          metadata: req_metadata,
          secret:
            InternalApi.Secrethub.Secret.new(
              metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "test"),
              data:
                InternalApi.Secrethub.Secret.Data.new(
                  env_vars: [
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "A", value: "test"),
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "B", value: ""),
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "", value: "C-test")
                  ]
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.create(channel, req)

      assert response.metadata.status.code == :FAILED_PRECONDITION
      assert response.metadata.status.message =~ "value can't be blank"
    end

    test "with invalid env_var name => it raises an error" do
      req_metadata = req_meta()

      req =
        InternalApi.Secrethub.CreateRequest.new(
          metadata: req_metadata,
          secret:
            InternalApi.Secrethub.Secret.new(
              metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "test"),
              data:
                InternalApi.Secrethub.Secret.Data.new(
                  env_vars: [
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "", value: "test"),
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "C-test", value: "test"),
                    InternalApi.Secrethub.Secret.EnvVar.new(name: "C_test", value: "test")
                  ]
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.create(channel, req, timeout: :infinity)

      assert response.metadata.status.code == :FAILED_PRECONDITION
      assert response.metadata.status.message =~ "name of enviorment variable is invalid"
    end

    test "with content too big => it raises an error" do
      req_metadata = req_meta()

      req =
        InternalApi.Secrethub.CreateRequest.new(
          metadata: req_metadata,
          secret:
            InternalApi.Secrethub.Secret.new(
              metadata: InternalApi.Secrethub.Secret.Metadata.new(name: "test"),
              data:
                InternalApi.Secrethub.Secret.Data.new(
                  env_vars: [
                    InternalApi.Secrethub.Secret.EnvVar.new(
                      name: "A",
                      value: String.duplicate("x", 1024 * 1024 * 3)
                    ),
                    InternalApi.Secrethub.Secret.EnvVar.new(
                      name: "B",
                      value: String.duplicate("x", 1024 * 1024 * 3)
                    ),
                    InternalApi.Secrethub.Secret.EnvVar.new(
                      name: "C",
                      value: String.duplicate("x", 1024 * 1024)
                    )
                  ]
                )
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.create(channel, req, timeout: :infinity)

      assert response.metadata.status.code == :FAILED_PRECONDITION
      assert response.metadata.status.message =~ "content is too big"
    end

    test "with project allow list" do
      req_metadata = req_meta()

      req =
        InternalApi.Secrethub.CreateRequest.new(
          metadata: req_metadata,
          secret:
            Support.Factories.InternalApi.with_org_options(
              Support.Factories.InternalApi.secret("aws-secrets")
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.create(channel, req)

      assert response.metadata.status.code == :OK

      {:ok, secret} = Secrethub.Secret.find(req_metadata.org_id, response.secret.metadata.id)

      assert response.secret.metadata.name == secret.name
      assert response.secret.metadata.id == secret.id
      assert response.secret.data.env_vars == req.secret.data.env_vars
      assert response.secret.data.files == req.secret.data.files
      assert response.secret.org_config.projects_access == req.secret.org_config.projects_access
      assert response.secret.org_config.project_ids == req.secret.org_config.project_ids
    end

    test "with job debug and attach set to NO" do
      req_metadata = req_meta()

      req =
        InternalApi.Secrethub.CreateRequest.new(
          metadata: req_metadata,
          secret:
            Support.Factories.InternalApi.with_org_options(
              Support.Factories.InternalApi.secret("aws-secrets"),
              debug_access: :JOB_DEBUG_NO,
              attach_access: :JOB_ATTACH_YES
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.create(channel, req)

      assert response.metadata.status.code == :OK

      {:ok, secret} = Secrethub.Secret.find(req_metadata.org_id, response.secret.metadata.id)

      assert response.secret.metadata.name == secret.name
      assert response.secret.metadata.id == secret.id
      assert response.secret.data.env_vars == req.secret.data.env_vars
      assert response.secret.data.files == req.secret.data.files
      assert response.secret.org_config.projects_access == req.secret.org_config.projects_access
      assert response.secret.org_config.project_ids == req.secret.org_config.project_ids
      assert response.secret.org_config.debug_access == req.secret.org_config.debug_access
      assert response.secret.org_config.attach_access == req.secret.org_config.attach_access
    end
  end

  describe ".update" do
    test "do not provide id in secret metadata" do
      {:ok, _} = Support.Factories.Secret.create("aws-1", @org_id)

      req =
        InternalApi.Secrethub.UpdateRequest.new(
          metadata: req_meta(),
          secret:
            Support.Factories.InternalApi.with_org_options(
              Support.Factories.InternalApi.secret("aws-secrets")
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.update(channel, req)

      assert response.metadata.status.code == :FAILED_PRECONDITION
      assert response.metadata.status.message == "secret id not provided"
    end

    test "secret that does not exist" do
      {:ok, _} = Support.Factories.Secret.create("aws-1", @org_id)

      req =
        InternalApi.Secrethub.UpdateRequest.new(
          metadata: req_meta(),
          secret:
            Support.Factories.InternalApi.with_org_options(
              Support.Factories.InternalApi.secret("aws-secrets", Ecto.UUID.generate())
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.update(channel, req)

      assert response.metadata.status.code == :NOT_FOUND
      assert response.metadata.status.message == "Secret #{req.secret.metadata.name} not found"
    end

    test "secret update without org_config does not update org_config" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      req =
        InternalApi.Secrethub.UpdateRequest.new(
          metadata: req_meta(s1.org_id),
          secret: Support.Factories.InternalApi.secret("aws-secrets", s1.id)
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.update(channel, req)

      assert response.metadata.status.code == :OK

      # check if contents are updated properly, and check if org_config is any different than it was
      {:ok, s_new} = Secrethub.Secret.find(s1.org_id, s1.id)
      assert s1.all_projects == s_new.all_projects
      assert s1.project_ids == s_new.project_ids
      assert s1.job_debug == s_new.job_debug
      assert s1.job_attach == s_new.job_attach
    end

    test "secret update with org_config" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      req =
        InternalApi.Secrethub.UpdateRequest.new(
          metadata: req_meta(s1.org_id),
          secret:
            Support.Factories.InternalApi.with_org_options(
              Support.Factories.InternalApi.secret("aws-secrets", s1.id)
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.update(channel, req)

      assert response.metadata.status.code == :OK

      # check if contents are updated properly, and check if org_config is any different than it was
      {:ok, s_new} = Secrethub.Secret.find(s1.org_id, s1.id)
      assert s_new.all_projects == false
      assert s_new.project_ids == req.secret.org_config.project_ids

      assert s_new.job_debug ==
               Secret.OrgConfig.JobDebugAccess.value(req.secret.org_config.debug_access)

      assert s_new.job_attach ==
               Secret.OrgConfig.JobAttachAccess.value(req.secret.org_config.attach_access)
    end
  end

  describe ".destroy" do
    test "when the secret exists => it deletes the secret" do
      {:ok, s1} = Support.Factories.Secret.create("aws-1", @org_id)

      req = DestroyRequest.new(metadata: req_meta(s1.org_id), name: "aws-1")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.destroy(channel, req)

      assert response.metadata.status.code == :OK

      assert {:error, :not_found} = Secrethub.Secret.find_by_name(s1.org_id, "aws-1")
    end

    test "when the secret doesn't exists => it returns not found" do
      req = DestroyRequest.new(metadata: req_meta(), name: "aws-1")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = SecretService.Stub.destroy(channel, req)

      assert response.metadata.status.code == :NOT_FOUND
    end
  end

  describe ".generate_openid_connect_token" do
    test "it returns a signed token, no AWS tags field" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      repo = "web"
      ref_type = "branch"
      git_ref = "refs/heads/main"

      req =
        GenerateOpenIDConnectTokenRequest.new(
          org_id: org_id,
          org_username: "testera",
          expire_in: 3600,
          subject:
            "org:testera:project:#{project_id}:repo:#{repo}:ref_type:#{ref_type}:ref:#{git_ref}",
          project_id: project_id,
          workflow_id: Ecto.UUID.generate(),
          pipeline_id: Ecto.UUID.generate(),
          job_id: Ecto.UUID.generate(),
          repository_name: repo,
          git_ref_type: ref_type,
          git_ref: git_ref,
          git_branch_name: "main",
          repo_slug: "renderedtext/#{repo}",
          job_type: "pipeline_job",
          project_name: "my-project"
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      assert {:ok, response} = SecretService.Stub.generate_open_id_connect_token(channel, req)
      assert {true, jwt, _} = Secrethub.OpenIDConnect.JWT.verify(response.token)

      now = epoch()

      assert Map.get(jwt.fields, "jti") != ""

      assert_in_delta Map.get(jwt.fields, "nbf"), now, 5
      assert_in_delta Map.get(jwt.fields, "iat"), now, 5
      assert_in_delta Map.get(jwt.fields, "exp") + req.expires_in, now, 5

      assert Map.get(jwt.fields, "prj_id") == req.project_id
      assert Map.get(jwt.fields, "org_id") == org_id
      assert Map.get(jwt.fields, "wf_id") == req.workflow_id
      assert Map.get(jwt.fields, "ppl_id") == req.pipeline_id
      assert Map.get(jwt.fields, "job_id") == req.job_id
      assert Map.get(jwt.fields, "job_type") == req.job_type
      assert Map.get(jwt.fields, "aud") == "https://testera.localhost"
      assert Map.get(jwt.fields, "iss") == "https://testera.localhost"

      assert Map.get(jwt.fields, "sub") == req.subject

      assert Map.get(jwt.fields, "sub127") ==
               "testera:#{project_id}:#{repo}:br:heads/main"

      assert Map.get(jwt.fields, "prj") == req.project_name
      assert Map.get(jwt.fields, "org") == req.org_username
      refute Map.has_key?(jwt.fields, "https://aws.amazon.com/tags")
    end

    test "it returns a signed token, with AWS tags field" do
      Support.FakeServices.enable_features(["open_id_connect_aws_tags"])
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      repo = "my-repo"
      ref_type = "branch"
      git_ref = "refs/heads/main"

      req =
        GenerateOpenIDConnectTokenRequest.new(
          org_id: org_id,
          org_username: "testera",
          expire_in: 3600,
          subject:
            "org:testera:project:#{project_id}:repo:#{repo}:ref_type:#{ref_type}:ref:#{git_ref}",
          project_id: project_id,
          workflow_id: Ecto.UUID.generate(),
          pipeline_id: Ecto.UUID.generate(),
          job_id: Ecto.UUID.generate(),
          git_branch_name: "main",
          repository_name: repo,
          git_ref_type: ref_type,
          git_ref: git_ref,
          job_type: "debug_job",
          repo_slug: "renderedtext/front",
          triggerer: "h:f,i:f"
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      assert {:ok, response} = SecretService.Stub.generate_open_id_connect_token(channel, req)
      assert {true, jwt, _} = Secrethub.OpenIDConnect.JWT.verify(response.token)

      now = epoch()

      assert Map.get(jwt.fields, "jti") != ""

      assert_in_delta Map.get(jwt.fields, "nbf"), now, 5
      assert_in_delta Map.get(jwt.fields, "iat"), now, 5
      assert_in_delta Map.get(jwt.fields, "exp") + req.expires_in, now, 5

      assert Map.get(jwt.fields, "prj_id") == req.project_id
      assert Map.get(jwt.fields, "wf_id") == req.workflow_id
      assert Map.get(jwt.fields, "ppl_id") == req.pipeline_id
      assert Map.get(jwt.fields, "job_id") == req.job_id
      assert Map.get(jwt.fields, "job_type") == req.job_type
      assert Map.get(jwt.fields, "trg") == req.triggerer

      assert Map.get(jwt.fields, "https://aws.amazon.com/tags") == %{
               "principal_tags" => %{
                 "prj_id" => [req.project_id],
                 "repo" => [repo],
                 "branch" => [req.git_branch_name],
                 "ref_type" => [ref_type],
                 "job_type" => [req.job_type],
                 "pr_branch" => [""],
                 "repo_slug" => [req.repo_slug],
                 "trg" => [req.triggerer]
               },
               "transitive_tag_keys" => [
                 "prj_id",
                 "repo",
                 "branch",
                 "ref_type",
                 "job_type",
                 "pr_branch",
                 "repo_slug",
                 "trg"
               ]
             }

      assert Map.get(jwt.fields, "aud") == "https://testera.localhost"
      assert Map.get(jwt.fields, "iss") == "https://testera.localhost"

      assert Map.get(jwt.fields, "sub") == req.subject

      assert Map.get(jwt.fields, "sub127") ==
               "testera:#{project_id}:#{repo}:br:heads/main"
    end

    test "sub127 claim sanitizes values, trims refs/ prefix, caps lengths, and stays within 127 chars" do
      long_org = String.duplicate("org-with:colon:", 10)
      long_repo = String.duplicate("repo-with:colon:", 10)
      long_ref = "refs/" <> String.duplicate("feature/super-long:ref/", 12)
      project_id = Ecto.UUID.generate()

      req =
        GenerateOpenIDConnectTokenRequest.new(
          org_id: Ecto.UUID.generate(),
          org_username: long_org,
          expire_in: 3600,
          subject:
            "org:#{long_org}:project:#{project_id}:repo:#{long_repo}:ref_type:branch:ref:#{long_ref}",
          project_id: project_id,
          workflow_id: Ecto.UUID.generate(),
          pipeline_id: Ecto.UUID.generate(),
          job_id: Ecto.UUID.generate(),
          git_branch_name: "master",
          repository_name: long_repo,
          git_ref_type: "branch",
          git_ref: long_ref,
          job_type: "pipeline_job",
          repo_slug: "renderedtext/front",
          triggerer: "api"
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      assert {:ok, response} = SecretService.Stub.generate_open_id_connect_token(channel, req)
      assert {true, jwt, _} = Secrethub.OpenIDConnect.JWT.verify(response.token)

      claim = Map.fetch!(jwt.fields, "sub127")
      parts = String.split(claim, ":", parts: 5, trim: false)

      assert length(parts) == 5
      assert Enum.all?(parts, &(not String.contains?(&1, ":")))
      assert String.length(claim) <= 127

      expected_org =
        long_org
        |> String.replace(":", "")
        |> String.slice(0, 25)

      expected_repo =
        long_repo
        |> String.replace(":", "")
        |> String.slice(0, 25)

      expected_ref_full =
        long_ref
        |> String.replace(":", "")
        |> String.replace_prefix("refs/", "")

      expected_ref =
        expected_ref_full
        |> String.slice(0, 35)

      expected =
        Enum.join(
          [
            expected_org,
            String.slice(req.project_id, 0, 36),
            expected_repo,
            "br",
            expected_ref
          ],
          ":"
        )

      assert claim == expected
      assert Enum.at(parts, 0) == expected_org
      assert Enum.at(parts, 1) == String.slice(req.project_id, 0, 36)
      assert Enum.at(parts, 2) == expected_repo
      assert Enum.at(parts, 3) == "br"
      assert Enum.at(parts, 4) == expected_ref
      assert String.length(Enum.at(parts, 0)) <= 25
      assert String.length(Enum.at(parts, 2)) <= 25
      assert String.length(Enum.at(parts, 4)) <= 35

      assert Map.fetch!(jwt.fields, "sub") == req.subject
    end

    test "sub127 claim shortens ref types to two characters" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      for {ref_type, expected} <- [
            {"branch", "br"},
            {"tag", "tg"},
            {"pull_request", "pr"},
            {"pull-request", "pr"},
            {"custom", "cu"},
            {"", ""}
          ] do
        req =
          GenerateOpenIDConnectTokenRequest.new(
            org_id: org_id,
            org_username: "organization",
            expire_in: 3600,
            subject: "sub",
            project_id: project_id,
            workflow_id: Ecto.UUID.generate(),
            pipeline_id: Ecto.UUID.generate(),
            job_id: Ecto.UUID.generate(),
            repository_name: "repository",
            git_ref_type: ref_type,
            git_ref: "feature/example",
            job_type: "pipeline_job"
          )

        assert {:ok, response} = SecretService.Stub.generate_open_id_connect_token(channel, req)
        assert {true, jwt, _} = Secrethub.OpenIDConnect.JWT.verify(response.token)

        claim = Map.fetch!(jwt.fields, "sub127")
        [_org, _project, _repo, actual, _ref] = String.split(claim, ":", parts: 5, trim: false)
        assert actual == expected
      end
    end

    test "it returns a signed token with filtered claims in on_prem mode" do
      Support.FakeServices.enable_features(["open_id_connect_aws_tags", "open_id_connect_filter"])
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      repo = "my-repo"
      ref_type = "branch"
      git_ref = "refs/heads/master"

      req =
        GenerateOpenIDConnectTokenRequest.new(
          org_id: org_id,
          org_username: "testera",
          expire_in: 3600,
          subject:
            "org:testera:project:#{project_id}:repo:#{repo}:ref_type:#{ref_type}:ref:#{git_ref}",
          project_id: project_id,
          workflow_id: Ecto.UUID.generate(),
          pipeline_id: Ecto.UUID.generate(),
          job_id: Ecto.UUID.generate(),
          git_branch_name: "master",
          repository_name: repo,
          git_ref_type: ref_type,
          git_ref: git_ref,
          job_type: "debug_job",
          repo_slug: "renderedtext/front",
          triggerer: "h:f-i:f",
          project_name: "front"
        )

      with_mock Secrethub, on_prem?: fn -> true end do
        {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        assert {:ok, response} = SecretService.Stub.generate_open_id_connect_token(channel, req)
        assert {true, jwt, _} = Secrethub.OpenIDConnect.JWT.verify(response.token)

        now = epoch()

        # Essential claims should be present
        assert Map.get(jwt.fields, "sub") == req.subject

        assert Map.get(jwt.fields, "sub127") ==
                 "testera:#{project_id}:#{repo}:br:heads/master"

        assert Map.get(jwt.fields, "aud") == "https://testera.localhost"
        assert Map.get(jwt.fields, "iss") == "https://testera.localhost"
        assert_in_delta Map.get(jwt.fields, "exp") + req.expires_in, now, 5
        assert_in_delta Map.get(jwt.fields, "nbf"), now, 5
        assert_in_delta Map.get(jwt.fields, "iat"), now, 5

        # Project related claims should be present
        assert Map.get(jwt.fields, "prj_id") == req.project_id
        assert Map.get(jwt.fields, "job_type") == req.job_type
        assert Map.get(jwt.fields, "org_id") == org_id
        refute Map.has_key?(jwt.fields, "prj")
        refute Map.has_key?(jwt.fields, "org")

        # AWS tags should be filtered
        aws_tags = Map.get(jwt.fields, "https://aws.amazon.com/tags")
        assert aws_tags != nil

        principal_tags = Map.get(aws_tags, "principal_tags")
        assert principal_tags != nil
        assert Map.get(principal_tags, "prj_id") == [req.project_id]
        assert Map.get(principal_tags, "branch") == [req.git_branch_name]
        assert Map.get(principal_tags, "job_type") == [req.job_type]
        refute Map.has_key?(principal_tags, "repo")
        refute Map.has_key?(principal_tags, "pr_branch")

        transitive_tags = Map.get(aws_tags, "transitive_tag_keys")
        assert transitive_tags != nil
        assert "prj_id" in transitive_tags
        assert "branch" in transitive_tags
        assert "job_type" in transitive_tags
        assert "ref_type" in transitive_tags
        assert "repo_slug" in transitive_tags
        assert "trg" in transitive_tags
        refute "repo" in transitive_tags
        refute "pr_branch" in transitive_tags
      end
    end

    test "it includes the kid in the header of the token" do
      org_id = Ecto.UUID.generate()

      req =
        GenerateOpenIDConnectTokenRequest.new(
          org_id: org_id,
          org_username: "testera",
          expire_in: 3600,
          subject: "project:front:pipeline:semaphore.yml",
          project_id: Ecto.UUID.generate(),
          workflow_id: Ecto.UUID.generate(),
          pipeline_id: Ecto.UUID.generate(),
          job_id: Ecto.UUID.generate()
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      assert {:ok, response} = SecretService.Stub.generate_open_id_connect_token(channel, req)

      kid = Secrethub.OpenIDConnect.KeyManager.active_key(:openid_keys).id

      assert {:ok, %{"kid" => ^kid, "alg" => "RS256"}} = Joken.peek_header(response.token)
    end

    defp epoch, do: :os.system_time(:second)
  end

  describe ".update_jwt_config" do
    setup do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      %{org_id: org_id, project_id: project_id, channel: channel}
    end

    test "with valid request updates JWT configuration", %{
      org_id: org_id,
      project_id: project_id,
      channel: channel
    } do
      claim_config =
        ClaimConfig.new(
          name: "custom_claim",
          description: "Test custom claim",
          is_active: true,
          is_mandatory: true,
          is_aws_tag: false,
          is_system_claim: true
        )

      req =
        UpdateJWTConfigRequest.new(
          org_id: org_id,
          project_id: project_id,
          claims: [claim_config],
          is_active: true
        )

      {:ok, response} = SecretService.Stub.update_jwt_config(channel, req)
      assert response.org_id == org_id
      assert response.project_id == project_id
    end

    test "with empty org_id returns error", %{project_id: project_id, channel: channel} do
      claim_config =
        ClaimConfig.new(
          name: "custom_claim",
          description: "Test custom claim",
          is_active: true,
          is_mandatory: true,
          is_aws_tag: false,
          is_system_claim: true
        )

      req =
        UpdateJWTConfigRequest.new(
          org_id: "",
          project_id: project_id,
          claims: [claim_config],
          is_active: true
        )

      assert {:error,
              %GRPC.RPCError{
                status: 3,
                __exception__: true,
                message: "Organization ID is required"
              }} = SecretService.Stub.update_jwt_config(channel, req)
    end

    test "with invalid claim configuration returns error", %{
      org_id: org_id,
      project_id: project_id,
      channel: channel
    } do
      # First set up a valid config to ensure we're starting clean
      valid_config =
        ClaimConfig.new(
          name: "test_claim",
          description: "Test claim",
          is_active: true,
          is_mandatory: true,
          is_aws_tag: false,
          is_system_claim: true
        )

      valid_req =
        UpdateJWTConfigRequest.new(
          org_id: org_id,
          project_id: project_id,
          claims: [valid_config],
          is_active: true
        )

      {:ok, _} = SecretService.Stub.update_jwt_config(channel, valid_req)

      # Test cases for invalid configurations
      invalid_configs = [
        {
          "Test empty name",
          [
            ClaimConfig.new(
              name: "",
              description: "Test description",
              is_active: true,
              is_mandatory: true,
              is_aws_tag: false,
              is_system_claim: true
            )
          ]
        }
      ]

      for {test_case, claims} <- invalid_configs do
        req =
          UpdateJWTConfigRequest.new(
            org_id: org_id,
            project_id: project_id,
            claims: claims,
            is_active: true
          )

        {:error, error} = SecretService.Stub.update_jwt_config(channel, req)

        assert %GRPC.RPCError{message: "Failed to update JWT config: :invalid_claims", status: 13} =
                 error,
               "Expected internal error for #{test_case}"
      end

      # Verify the original valid claim is still there and unchanged
      get_req =
        GetJWTConfigRequest.new(
          org_id: org_id,
          project_id: project_id
        )

      {:ok, response} = SecretService.Stub.get_jwt_config(channel, get_req)

      assert Enum.any?(response.claims, fn claim ->
               claim == %InternalApi.Secrethub.ClaimConfig{
                 name: "test_claim",
                 description: "Test claim",
                 is_active: true,
                 # can't update for non system claims
                 is_mandatory: false,
                 is_aws_tag: false,
                 is_system_claim: false
               }
             end)
    end
  end

  describe ".get_jwt_config" do
    setup do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      # Set up initial JWT configuration
      claim_config =
        ClaimConfig.new(
          name: "custom_claim",
          description: "Test custom claim",
          is_active: true,
          is_mandatory: true,
          is_aws_tag: false,
          is_system_claim: true
        )

      update_req =
        UpdateJWTConfigRequest.new(
          org_id: org_id,
          project_id: project_id,
          claims: [claim_config],
          is_active: true
        )

      {:ok, _} = SecretService.Stub.update_jwt_config(channel, update_req)

      %{org_id: org_id, project_id: project_id, channel: channel, claim_config: claim_config}
    end

    test "retrieves JWT configuration for valid project", %{
      org_id: org_id,
      project_id: project_id,
      channel: channel,
      claim_config: expected_claim
    } do
      req =
        GetJWTConfigRequest.new(
          org_id: org_id,
          project_id: project_id
        )

      {:ok, response} = SecretService.Stub.get_jwt_config(channel, req)

      assert response.org_id == org_id
      assert response.project_id == project_id
      assert response.is_active == true

      assert Enum.any?(response.claims, fn claim ->
               Map.take(claim, Map.keys(expected_claim)) == %InternalApi.Secrethub.ClaimConfig{
                 name: expected_claim.name,
                 description: expected_claim.description,
                 is_active: expected_claim.is_active,
                 # can't update for non system claims
                 is_mandatory: false,
                 is_aws_tag: false,
                 is_system_claim: false
               }
             end)
    end

    test "returns org config for non-existent project", %{org_id: org_id, channel: channel} do
      # First create organization configuration
      org_req =
        UpdateJWTConfigRequest.new(
          org_id: org_id,
          project_id: "",
          claims: [
            ClaimConfig.new(
              name: "custom_claim",
              description: "Test custom claim",
              is_active: true,
              is_mandatory: true,
              is_aws_tag: false,
              is_system_claim: true
            )
          ],
          is_active: true
        )

      {:ok, _} = SecretService.Stub.update_jwt_config(channel, org_req)

      # Now test non-existent project
      non_existent_project = Ecto.UUID.generate()

      req =
        GetJWTConfigRequest.new(
          org_id: org_id,
          project_id: non_existent_project
        )

      # Since there's no project config, we should get back the org config
      {:ok, response} = SecretService.Stub.get_jwt_config(channel, req)
      assert response.org_id == org_id
      refute is_nil(response.project_id), "Expected project_id not to be nil"

      expected_claim = %{
        name: "custom_claim",
        description: "Test custom claim",
        is_active: true,
        is_mandatory: false,
        is_aws_tag: false,
        is_system_claim: false
      }

      assert Enum.any?(response.claims, fn claim ->
               Map.take(claim, Map.keys(expected_claim)) == expected_claim
             end)
    end

    test ".get_jwt_config returns error for empty org_id" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      project_id = Ecto.UUID.generate()

      req =
        GetJWTConfigRequest.new(
          org_id: "",
          project_id: project_id
        )

      assert {:error,
              %GRPC.RPCError{
                status: 3,
                __exception__: true,
                message: "Organization ID is required"
              }} = SecretService.Stub.get_jwt_config(channel, req)
    end
  end

  describe "get_key/2" do
    alias InternalApi.Secrethub.GetKeyRequest
    alias InternalApi.Secrethub.GetKeyResponse

    @keys_path "priv/secret_keys_in_tests"
    @vault_path "/tmp/vault_keys"
    @invalid_key_id 1_666_780_781
    @valid_key_id 1_666_780_782

    setup do
      Application.put_env(:secrethub, Secrethub.KeyVault, keys_path: @vault_path)
      File.mkdir!(@vault_path)

      on_exit(fn ->
        Application.put_env(:secrethub, Secrethub.KeyVault, nil)
        File.rm_rf!(@vault_path)
      end)
    end

    test "when everything is configured properly then returns the key" do
      copy_key(@valid_key_id)
      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, response} = SecretService.Stub.get_key(channel, GetKeyRequest.new())

      assert %GetKeyResponse{id: "1666780782", key: key} = response
      assert is_binary(key)
    end

    test "when something goes wrong then returns the error" do
      copy_key(@invalid_key_id)
      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      assert {:error, %GRPC.RPCError{status: 13, message: "Cannot fetch key"}} =
               SecretService.Stub.get_key(channel, GetKeyRequest.new())
    end

    defp copy_key(key_id) do
      copy_key_file(key_id, ".prv.pem")
      copy_key_file(key_id, ".pub.pem")
    end

    defp copy_key_file(key_id, ext) do
      filename = "#{key_id}#{ext}"
      File.copy!(Path.join(@keys_path, filename), Path.join(@vault_path, filename))
    end
  end
end
