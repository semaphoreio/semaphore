defmodule FrontWeb.AuditControllerTest do
  use ExUnit.Case, async: false

  use FrontWeb.ConnCase

  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    user_id = Map.get(user, :id)

    organization = DB.first(:organizations)
    org_id = Map.get(organization, :id)

    Support.Stubs.Feature.enable_feature(org_id, :audit_logs)
    Support.Stubs.Feature.enable_feature(org_id, :audit_streaming)

    Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [
      conn: conn,
      org_id: org_id,
      user_id: user_id
    ]
  end

  describe "create audit log stream" do
    test "creates audit log stream", %{conn: conn, org_id: org_id} do
      conn =
        conn
        |> post(
          audit_path(conn, :create, %{
            "s3" => %{
              bucket: "my-bucket",
              key_id: "s3-key-id",
              key_secret: "s3-key-secret",
              host: "s3.aws.com",
              instance_role: false
            }
          })
        )

      assert redirected_to(conn, 302) =~ "/audit/streaming"

      conn =
        conn
        |> get(audit_path(conn, :show))

      assert conn.assigns.stream.stream == %{
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
             }
    end

    test "creates audit log stream using instance role", %{
      conn: conn,
      org_id: org_id
    } do
      conn =
        conn
        |> post(
          audit_path(conn, :create, %{
            "s3" => %{
              bucket: "my-bucket",
              instance_role: true,
              region: "us-east-1"
            }
          })
        )

      assert redirected_to(conn, 302) =~ "/audit/streaming"

      conn =
        conn
        |> get(audit_path(conn, :show))

      assert conn.assigns.stream.stream == %{
               org_id: org_id,
               provider: :S3,
               s3_config: %{
                 bucket: "my-bucket",
                 region: "us-east-1",
                 type: :INSTANCE_ROLE,
                 host: "",
                 key_id: "",
                 key_secret: ""
               },
               status: :ACTIVE
             }
    end
  end
end
