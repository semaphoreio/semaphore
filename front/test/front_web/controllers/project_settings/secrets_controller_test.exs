defmodule FrontWeb.ProjectSettings.SecretsControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    org_id = Support.Stubs.Organization.default_org_id()
    user_id = Support.Stubs.User.default_user_id()

    project = DB.first(:projects)

    project_name =
      project
      |> Map.get(:name)

    project_id =
      project
      |> Map.get(:id)

    conn =
      conn
      |> Plug.Conn.put_req_header("x-semaphore-user-id", user_id)
      |> Plug.Conn.put_req_header("x-semaphore-org-id", org_id)

    [
      conn: conn,
      org_id: org_id,
      user_id: user_id,
      project_id: project_id,
      project_name: project_name
    ]
  end

  describe "GET when project level secrets are not enabled" do
    setup data do
      Support.Stubs.Feature.disable_feature(data.org_id, :project_level_secrets)

      on_exit(fn ->
        Support.Stubs.Feature.enable_feature(data.org_id, :project_level_secrets)
      end)

      data
    end

    test "GET secrets - when the user is not authorized => renders 404", %{
      conn: conn,
      project_name: project_name
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get(secrets_path(conn, :index, project_name))

      assert html_response(conn, 404) =~ "404"
    end

    test "GET secrets - when the user is authorized => renders the page", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.Feature.enable_feature(org_id, :permission_patrol)
      Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

      conn =
        conn
        |> get(secrets_path(conn, :index, project_name))

      assert html_response(conn, 200) =~ "Secrets you define will be available"
    end
  end

  describe "GET when project level secrets are enabled" do
    test "GET secrets - when the user is not authorized => renders 404", %{
      conn: conn,
      project_name: project_name
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get(secrets_path(conn, :index, project_name))

      assert html_response(conn, 404) =~ "404"
    end

    test "GET secrets - when the user is authorized => renders the page", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.Feature.enable_feature(org_id, :permission_patrol)
      Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

      conn =
        conn
        |> get(secrets_path(conn, :index, project_name))

      assert html_response(conn, 200) =~
               "Secrets authorized by your organization admins to be used on this project"

      assert html_response(conn, 200) =~
               "Secrets allow you to store and safely inject sensitive information into your jobs."
    end

    test "it shows the new secret form", %{conn: conn, project_name: project_name} do
      conn =
        conn
        |> get(secrets_path(conn, :new, project_name))

      assert html_response(conn, 200) =~ "Create Project Secret"
      assert html_response(conn, 200) =~ "Name of the Secret"
      assert html_response(conn, 200) =~ "Save Secret"
      assert html_response(conn, 200) =~ "Environment Variables"
      assert html_response(conn, 200) =~ "Files"
    end

    test "when the user is not authorized to create a secret in the org => renders 404", %{
      conn: conn,
      project_name: project_name
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get(secrets_path(conn, :new, project_name))

      assert html_response(conn, 404) =~ "404"
    end

    test "it creates a secret with correct params", %{conn: conn, project_name: project_name} do
      conn =
        conn
        |> post(secrets_path(conn, :create, project_name),
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

      assert redirected_to(conn) == secrets_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Secret created."
    end

    test "when params don't meet UI side validation criteria, it returns 422, displays the new secret page with user-provided params and alerts",
         %{conn: conn, project_name: project_name} do
      conn =
        conn
        |> post(secrets_path(conn, :create, project_name),
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

    test "when the creation fails => returns 422, opens the new secret page with user-provided params and alerts",
         %{conn: conn, project_name: project_name} do
      GrpcMock.stub(SecretMock, :create, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> post(secrets_path(conn, :create, project_name),
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

    test "it shows the edit secret form", %{
      conn: conn,
      project_name: project_name,
      project_id: project_id
    } do
      secret = create_project_secret(project_id)

      conn =
        conn
        |> get(secrets_path(conn, :edit, project_name, secret.id))

      assert html_response(conn, 200) =~ "Editing Secret #{secret.name}"
      assert html_response(conn, 200) =~ "Name of the Secret"
      assert html_response(conn, 200) =~ "Save Secret"
      assert html_response(conn, 200) =~ "Environment Variables"
      assert html_response(conn, 200) =~ "Files"
      assert html_response(conn, 200) =~ secret.name
      assert html_response(conn, 200) =~ hd(secret.api_model.data.env_vars).name
      refute html_response(conn, 200) =~ hd(secret.api_model.data.env_vars).value
    end

    test "when the secret doesn't exist or the user has no access => renders 404", %{
      conn: conn,
      project_name: project_name
    } do
      conn =
        conn
        |> get(secrets_path(conn, :edit, project_name, Ecto.UUID.generate()))

      assert html_response(conn, 404) =~ "404"
    end

    test "when the update succeeds => redirets with note", %{
      conn: conn,
      project_name: project_name,
      project_id: project_id
    } do
      secret = create_project_secret(project_id)

      conn =
        conn
        |> put(secrets_path(conn, :update, project_name, secret.id),
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

      assert redirected_to(conn) == secrets_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Secret updated."
    end

    test "when the update fails bc of invalid params => redirets back to page with note", %{
      conn: conn,
      project_name: project_name,
      project_id: project_id
    } do
      GrpcMock.stub(SecretMock, :update, fn _, _ ->
        %{metadata: %{status: %{code: :FAILED_PRECONDITION, message: "Invalid"}}}
        |> Util.Proto.deep_new!(InternalApi.Secrethub.UpdateResponse)
      end)

      secret = create_project_secret(project_id)

      conn =
        conn
        |> put(secrets_path(conn, :update, project_name, secret.id),
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

      assert redirected_to(conn) == secrets_path(conn, :edit, project_name, secret.id)
      assert get_flash(conn, :alert) == "Failed: Invalid"
    end

    test "when deletion succeds => it redirects with note", %{
      conn: conn,
      project_name: project_name,
      project_id: project_id
    } do
      secret = create_project_secret(project_id)

      conn =
        conn
        |> delete(secrets_path(conn, :delete, project_name, secret.id))

      assert redirected_to(conn) == secrets_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Secret deleted."
    end

    test "when deletion fails => redirects back to index page with note", %{
      conn: conn,
      project_name: project_name,
      project_id: project_id
    } do
      GrpcMock.stub(SecretMock, :destroy, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      secret = create_project_secret(project_id)

      conn =
        conn
        |> delete(secrets_path(conn, :delete, project_name, secret.id))

      assert redirected_to(conn) == secrets_path(conn, :index, project_name)
      assert get_flash(conn, :alert) == "Failed to delete secret."
    end

    test "when deletion fails with not found => renders 404", %{
      conn: conn,
      project_name: project_name,
      project_id: _project_id
    } do
      conn =
        conn
        |> delete(secrets_path(conn, :delete, project_name, Ecto.UUID.generate()))

      assert html_response(conn, 404) =~ "404"
    end
  end

  defp create_project_secret(project_id) do
    Support.Stubs.Secret.create("pouch-of-secrets", %{
      level: :PROJECT,
      project_id: project_id
    })
  end
end
