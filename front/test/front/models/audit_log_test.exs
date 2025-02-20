defmodule Front.Models.AuditLogTest do
  use Front.TestCase
  doctest Front.Models.AuditLog
  alias Front.Models.AuditLog

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    Support.Stubs.Feature.enable_feature(org_id, :audit_logs)

    [
      org_id: org_id,
      user_id: user_id
    ]
  end

  describe "describe" do
    test "describe created audit log stream with credentials", %{org_id: org_id, user_id: user_id} do
      assert {:ok, created_stream} =
               AuditLog.create(org_id, user_id, %Front.Models.AuditLog.S3{
                 bucket: "my-bucket",
                 key_id: "s3-key-id",
                 key_secret: "s3-key-secret",
                 host: "s3.aws.com"
               })

      assert %{
               org_id: org_id,
               provider: :S3,
               s3_config: %{
                 bucket: "my-bucket",
                 host: "s3.aws.com",
                 key_id: "s3-key-id",
                 key_secret: "s3-key-secret",
                 region: "",
                 type: :USER
               },
               status: :ACTIVE
             } == created_stream

      assert {:ok, described_stream} = AuditLog.describe(org_id)

      assert %{
               meta: %{
                 activity_toggled_by: "78114608-be8a-465a-b9cd-81970fb802c5",
                 updated_by: "78114608-be8a-465a-b9cd-81970fb802c5"
               },
               stream: %{
                 org_id: ^org_id,
                 provider: :S3,
                 s3_config: %{
                   bucket: "my-bucket",
                   host: "s3.aws.com",
                   key_id: "s3-key-id",
                   key_secret: "s3-key-secret",
                   region: "",
                   type: :USER
                 },
                 status: :ACTIVE
               }
             } = described_stream
    end

    test "describe created audit log stream with instance role", %{
      org_id: org_id,
      user_id: user_id
    } do
      assert {:ok, created_stream} =
               AuditLog.create(org_id, user_id, %Front.Models.AuditLog.S3{
                 bucket: "my-bucket",
                 region: "us-east-1",
                 instance_role: true
               })

      assert %{
               org_id: org_id,
               provider: :S3,
               s3_config: %{
                 bucket: "my-bucket",
                 host: "",
                 key_id: "",
                 key_secret: "",
                 region: "us-east-1",
                 type: :INSTANCE_ROLE
               },
               status: :ACTIVE
             } == created_stream

      assert {:ok, described_stream} = AuditLog.describe(org_id)

      assert %{
               meta: %{
                 activity_toggled_by: "78114608-be8a-465a-b9cd-81970fb802c5",
                 updated_by: "78114608-be8a-465a-b9cd-81970fb802c5"
               },
               stream: %{
                 org_id: ^org_id,
                 provider: :S3,
                 s3_config: %{
                   bucket: "my-bucket",
                   host: "",
                   key_id: "",
                   key_secret: "",
                   region: "us-east-1",
                   type: :INSTANCE_ROLE
                 },
                 status: :ACTIVE
               }
             } = described_stream
    end
  end
end
