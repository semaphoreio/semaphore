defmodule FrontWeb.SecretsControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user_id = DB.first(:users) |> Map.get(:id)
    org_id = DB.first(:organizations) |> Map.get(:id)

    Support.Stubs.PermissionPatrol.remove_all_permissions()

    Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
      "organization.view",
      "organization.secrets.view"
    ])

    secret = DB.first(:secrets)
    secret_name = Map.get(secret, :name)
    secret_id = Map.get(secret, :id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [
      conn: conn,
      secret_name: secret_name,
      secret_id: secret_id,
      org_id: org_id,
      user_id: user_id
    ]
  end

  describe "GET index" do
    test "when there are secrets => shows them", %{conn: conn, secret_name: secret_name} do
      conn =
        conn
        |> get("/secrets")

      assert html_response(conn, 200) =~ secret_name
      refute html_response(conn, 200) =~ "No Secrets configured"
    end

    test "when there are no secrets => shows the copy", %{
      conn: conn,
      secret_name: secret_name,
      secret_id: secret_id
    } do
      DB.delete(:secrets, secret_id)

      conn =
        conn
        |> get("/secrets")

      refute html_response(conn, 200) =~ secret_name
      assert html_response(conn, 200) =~ "No Secrets configured"
    end

    test "when the user is not authorized to view the org => show message", %{
      conn: conn,
      user_id: user_id,
      org_id: org_id
    } do
      DB.clear(:user_permissions_key_value_store)
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, "organization.view")

      conn =
        conn
        |> get("/secrets")

      assert html_response(conn, 200) =~ "Sorry, you can’t access Secrets"
    end
  end

  describe "GET new" do
    test "it shows the new secret form", %{conn: conn, org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(
        org_id,
        user_id,
        "organization.secrets.manage"
      )

      conn =
        conn
        |> get("/secrets/new")

      assert html_response(conn, 200) =~ "Create Secret"
      assert html_response(conn, 200) =~ "Name of the Secret"
      assert html_response(conn, 200) =~ "Save Secret"
      assert html_response(conn, 200) =~ "Environment Variables"
      assert html_response(conn, 200) =~ "Files"
    end

    test "when the user is not authorized to create a secret in the org => show message", %{
      conn: conn
    } do
      conn =
        conn
        |> get("/secrets/new")

      assert html_response(conn, 200) =~ "Sorry, you can’t manage Secrets."
    end
  end

  describe "POST create" do
    setup %{user_id: user_id, org_id: org_id} = config do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.secrets.manage",
        "organization.secrets_policy_settings.manage"
      ])

      config
    end

    test "it creates a secret with correct params", %{conn: conn} do
      conn =
        conn
        |> post("/secrets",
          name: "New Secret Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Secret created."
    end

    test "when only env vars are posted => it creates normally", %{conn: conn} do
      conn =
        conn
        |> post("/secrets",
          name: "New Secret Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"}
          }
        )

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Secret created."
    end

    test "when there are empty or half empty fields => those are ignored", %{conn: conn} do
      conn =
        conn
        |> post("/secrets",
          name: "New Secret Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "", "value" => ""}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "", "content" => "bbb"}
          }
        )

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Secret created."
    end

    test "when params don't meet UI side validation criteria, it returns 422, displays the new secret page with user-provided params and alerts",
         %{conn: conn} do
      conn =
        conn
        |> post("/secrets",
          name: "",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"}
          }
        )

      assert html_response(conn, 422) =~ "AWS"
      assert html_response(conn, 422) =~ "Required. Cannot be empty."
      assert get_flash(conn, :alert) == "Failed to create the secret."
    end

    test "when the creation fails with permission denied => renders 404", %{conn: conn} do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        raise GRPC.RPCError, status: 7, message: "Denied"
      end)

      conn =
        conn
        |> post("/secrets",
          name: "New Secret Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when the creation fails => returns 422, opens the new secret page with user-provided params and alerts",
         %{conn: conn} do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> post("/secrets",
          name: "New Secret Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert html_response(conn, 422) =~ "Unknown"
      assert html_response(conn, 422) =~ "GCLOUD"
      assert get_flash(conn, :alert) == "Failed: Unknown"
    end

    test "when the creation fails bc of invalid name param => opens the new secrets page, displays user-provided params, alerts and shows error",
         %{conn: conn} do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        %{metadata: %{status: %{code: :FAILED_PRECONDITION, message: "Invalid name"}}}
        |> Util.Proto.deep_new!(InternalApi.Secrethub.CreateResponse)
      end)

      conn =
        conn
        |> post("/secrets",
          name: "New Secret Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert html_response(conn, 422) =~ "Invalid name"
      assert get_flash(conn, :alert) == "Failed to create the secret."
    end

    test "when the creation fails with invalid params error response that is not about the name field => returns 422, opens the new secret page with user-provided params and alerts",
         %{conn: conn} do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        %{metadata: %{status: %{code: :FAILED_PRECONDITION, message: "Invalid"}}}
        |> Util.Proto.deep_new!(InternalApi.Secrethub.CreateResponse)
      end)

      conn =
        conn
        |> post("/secrets",
          name: "New Secret Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert html_response(conn, 422) =~ "Invalid"
      assert html_response(conn, 422) =~ "GCLOUD"
      assert get_flash(conn, :alert) == "Failed: Invalid"
    end

    test "create without name and fail",
         %{conn: conn} do
      conn =
        conn
        |> post("/secrets",
          name: "",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          },
          projects_access: "ALL",
          attach_access: "JOB_ATTACH_YES",
          debug_access: "JOB_DEBUG_YES"
        )

      assert html_response(conn, 422) =~ "Required. Cannot be empty."
      assert get_flash(conn, :alert) == "Failed to create the secret."
    end
  end

  describe "GET edit" do
    setup %{user_id: user_id, org_id: org_id} = config do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.secrets.manage",
        "organization.secrets_policy_settings.manage"
      ])

      config
    end

    test "it shows the edit secret form", %{conn: conn, secret_id: secret_id} do
      conn =
        conn
        |> get("/secrets/#{secret_id}/edit")

      assert html_response(conn, 200) =~ "Edit Secret"
      assert html_response(conn, 200) =~ "Name of the Secret"
      assert html_response(conn, 200) =~ "Save Secret"
      assert html_response(conn, 200) =~ "Environment Variables"
      assert html_response(conn, 200) =~ "Files"
      assert html_response(conn, 200) =~ "secret-1"
      refute html_response(conn, 200) =~ "hello"
    end

    test "when the secret doesn't exist or the user has no access => renders 404", %{conn: conn} do
      conn =
        conn
        |> get("/secrets/78114608-be8a-465a-b9cd-81970fb802b2/edit")

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "PUT update" do
    setup %{user_id: user_id, org_id: org_id} = config do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.secrets.manage",
        "organization.secrets_policy_settings.manage"
      ])

      config
    end

    test "when user does not have permissions => redirects with note", %{
      conn: conn,
      secret_id: secret_id,
      org_id: org_id,
      user_id: user_id
    } do
      DB.clear(:user_permissions_key_value_store)

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.view",
        "organization.secrets.view"
      ])

      conn =
        conn
        |> put("/secrets/#{secret_id}",
          name: "Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Insufficient permissions."
    end

    test "when the update succeeds => redirets with note", %{conn: conn, secret_id: secret_id} do
      conn =
        conn
        |> put("/secrets/#{secret_id}",
          name: "Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Secret updated."
    end

    test "when the update bc the secret is not found => renders 404", %{conn: conn} do
      conn =
        conn
        |> put("/secrets/78114608-be8a-465a-b9cd-81970fb802b2",
          name: "Name",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when the update fails bc of invalid params => redirets back to page with note", %{
      conn: conn,
      secret_id: secret_id
    } do
      GrpcMock.stub(SecretMock, :update, fn _, _ ->
        %{metadata: %{status: %{code: :FAILED_PRECONDITION, message: "Invalid"}}}
        |> Util.Proto.deep_new!(InternalApi.Secrethub.UpdateResponse)
      end)

      conn =
        conn
        |> put("/secrets/#{secret_id}",
          name: "Invalid",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert redirected_to(conn) == "/secrets/#{secret_id}/edit"
      assert get_flash(conn, :alert) == "Failed: Invalid"
    end

    test "when the update fails bc of unknown error => redirets back to page with note", %{
      conn: conn,
      secret_id: secret_id
    } do
      GrpcMock.stub(SecretMock, :update, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> put("/secrets/#{secret_id}",
          name: "Unknown",
          env_vars: %{
            "1" => %{"name" => "AWS", "value" => "123"},
            "2" => %{"name" => "GCLOUD", "value" => "456"}
          },
          files: %{
            "1" => %{"path" => "/var/lib/", "content" => "aaa"},
            "2" => %{"path" => "/tmp/", "content" => "bbb"}
          }
        )

      assert redirected_to(conn) == "/secrets/#{secret_id}/edit"
      assert get_flash(conn, :alert) == "Secret operation failed."
    end
  end

  describe "DELETE destroy" do
    setup %{user_id: user_id, org_id: org_id} = config do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.secrets.manage",
        "organization.secrets_policy_settings.manage"
      ])

      config
    end

    test "when user does not have permissions => redirects with note", %{
      conn: conn,
      secret_id: secret_id,
      org_id: org_id,
      user_id: user_id
    } do
      DB.clear(:user_permissions_key_value_store)

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.view",
        "organization.secrets.view"
      ])

      conn =
        conn
        |> delete("/secrets/#{secret_id}")

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Insufficient permissions."
    end

    test "when the deletion succeeds => redirects with note", %{conn: conn, secret_id: secret_id} do
      conn =
        conn
        |> delete("/secrets/#{secret_id}")

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Secret deleted."
    end

    test "when the deletion fails => redirects back to show page with note", %{
      conn: conn,
      secret_id: secret_id
    } do
      GrpcMock.stub(SecretMock, :destroy, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> delete("/secrets/#{secret_id}")

      assert redirected_to(conn) == "/secrets"
      assert get_flash(conn, :notice) == "Failed to delete secret."
    end

    test "when the deletion fails with not found => renders 404", %{conn: conn} do
      conn =
        conn
        |> delete("/secrets/78114608-be8a-465a-b9cd-81970fb802b2")

      assert html_response(conn, 404) =~ "404"
    end
  end
end
