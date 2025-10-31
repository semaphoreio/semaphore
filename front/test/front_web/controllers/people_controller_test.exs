defmodule FrontWeb.PeopleControllerTest do
  use FrontWeb.ConnCase
  import Mock
  alias Support.Stubs.{DB, PermissionPatrol, Project}

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()
    project = DB.first(:projects)

    other_user = Support.Stubs.User.create(name: "Other User")
    Support.Stubs.RBAC.add_member(organization.id, other_user.id)
    PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

    non_member = Support.Stubs.User.create(name: "Not Member")

    PermissionPatrol.allow_everything(organization.id, user.id)

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", organization.id)

    [
      conn: conn,
      organization: organization,
      user: user,
      other_user: other_user,
      non_member: non_member,
      project: project
    ]
  end

  describe "GET organization_users" do
    test "when the user can't access the org => returns 404", %{
      conn: conn
    } do
      PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get("/people/export")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user can access the org => send csv", %{
      conn: conn
    } do
      conn =
        conn
        |> get("/people/export")

      assert response_content_type(conn, :csv)

      rows =
        conn.resp_body
        |> String.split("\r\n", trim: true)
        |> CSV.decode!(validate_row_length: true, headers: true)
        |> Enum.to_list()

      assert length(rows) == 8

      first = List.first(rows)

      assert Map.has_key?(first, "name")
      assert Map.has_key?(first, "email")
      assert Map.has_key?(first, "github_login")
      assert Map.has_key?(first, "bitbucket_login")
      assert Map.has_key?(first, "gitlab_login")
    end
  end

  describe "GET show" do
    test "when the user can't access the org => returns 404", %{
      conn: conn,
      organization: organization,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      conn =
        conn
        |> get("/people/#{other_user.id}")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is a memeber, but can't manage people => show page without buttons", %{
      conn: conn,
      organization: organization,
      user: user,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> get("/people/#{other_user.id}")

      assert html_response(conn, 200) =~ other_user.name
      refute html_response(conn, 200) =~ "Save changes"
      refute html_response(conn, 200) =~ "Reset API Token"
      refute html_response(conn, 200) =~ "Reset Password"
    end

    test "user with manage people permission => show page with buttons", %{
      conn: conn,
      other_user: other_user
    } do
      conn =
        conn
        |> get("/people/#{other_user.id}")

      assert html_response(conn, 200) =~ other_user.name
      refute html_response(conn, 200) =~ "Save changes"
      assert html_response(conn, 200) =~ "Reset Password"
      refute html_response(conn, 200) =~ "Reset API Token"
    end

    test "user with manage people permission when password is disabled => show page with buttons",
         %{
           conn: conn,
           organization: organization,
           other_user: other_user
         } do
      Support.Stubs.Feature.disable_feature(organization.id, :email_members)

      conn =
        conn
        |> get("/people/#{other_user.id}")

      assert html_response(conn, 200) =~ other_user.name
      refute html_response(conn, 200) =~ "Save changes"
      refute html_response(conn, 200) =~ "Reset Password"
      refute html_response(conn, 200) =~ "Reset API Token"

      Support.Stubs.Feature.enable_feature(organization.id, :email_members)
    end

    test "user on it's own page => show page with buttons", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> get("/people/#{user.id}")

      assert html_response(conn, 200) =~ user.name
      assert html_response(conn, 200) =~ "Save changes"
      assert html_response(conn, 200) =~ "Reset Password"
      assert html_response(conn, 200) =~ "Reset API Token"
    end

    test "user with manage people permission looking for profile of non member => returns 404", %{
      conn: conn,
      non_member: non_member
    } do
      conn =
        conn
        |> get("/people/#{non_member.id}")

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "POST update" do
    test "when the user can't access the org => returns 404", %{
      conn: conn,
      organization: organization,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      conn =
        conn
        |> post("/people/#{other_user.id}")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is a memeber, but can't manage people => returns 404", %{
      conn: conn,
      organization: organization,
      user: user,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> post("/people/#{other_user.id}")

      assert html_response(conn, 404) =~ "404"
    end

    test "user with manage people permission => returns 404", %{
      conn: conn,
      other_user: other_user
    } do
      conn =
        conn
        |> post("/people/#{other_user.id}")

      assert html_response(conn, 404) =~ "404"
    end

    test "user on it's own page => allow update", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> post("/people/#{user.id}?name=John")

      assert html_response(conn, 302) =~ "/people/#{user.id}"
    end

    test "user with manage people permission updating non member => returns 404", %{
      conn: conn,
      non_member: non_member
    } do
      conn =
        conn
        |> post("/people/#{non_member.id}")

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "POST reset_token" do
    test "when the user can't access the org => returns 404", %{
      conn: conn,
      organization: organization,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      conn =
        conn
        |> post("/people/#{other_user.id}/reset_token")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is a memeber, but can't manage people => returns 404", %{
      conn: conn,
      organization: organization,
      user: user,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> post("/people/#{other_user.id}/reset_token")

      assert html_response(conn, 404) =~ "404"
    end

    test "user with manage people permission => returns 404", %{
      conn: conn,
      other_user: other_user
    } do
      conn =
        conn
        |> post("/people/#{other_user.id}/reset_token")

      assert html_response(conn, 404) =~ "404"
    end

    test "user on it's own page => allow reset", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> post("/people/#{user.id}/reset_token")

      assert html_response(conn, 200) =~
               "For security reasons, we’ll show you the token only once."
    end

    test "user with manage people permission updating non member => returns 404", %{
      conn: conn,
      non_member: non_member
    } do
      conn =
        conn
        |> post("/people/#{non_member.id}/reset_token")

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "POST reset_password" do
    test "when the user can't access the org => returns 404", %{
      conn: conn,
      organization: organization,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      conn =
        conn
        |> post("/people/#{other_user.id}/reset_password")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is a memeber, but can't manage people => returns 404", %{
      conn: conn,
      organization: organization,
      user: user,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> post("/people/#{other_user.id}/reset_password")

      assert html_response(conn, 404) =~ "404"
    end

    test "user with manage people permission => allow reset", %{
      conn: conn,
      other_user: other_user
    } do
      conn =
        conn
        |> post("/people/#{other_user.id}/reset_password")

      assert html_response(conn, 200) =~
               "For security reasons, we’ll show you the password only once."
    end

    test "user with manage people permission but feature is disabled => returns 404", %{
      conn: conn,
      organization: organization,
      other_user: other_user
    } do
      Support.Stubs.Feature.disable_feature(organization.id, :email_members)

      conn =
        conn
        |> post("/people/#{other_user.id}/reset_password")

      assert html_response(conn, 404) =~ "404"

      Support.Stubs.Feature.enable_feature(organization.id, :email_members)
    end

    test "user on it's own page => allow reset", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> post("/people/#{user.id}/reset_password")

      assert html_response(conn, 200) =~
               "For security reasons, we’ll show you the password only once."
    end

    test "user with manage people permission updating non member => returns 404", %{
      conn: conn,
      non_member: non_member
    } do
      conn =
        conn
        |> post("/people/#{non_member.id}/reset_password")

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "POST change_email" do
    test "user trying to change another user's email => returns error", %{
      conn: conn,
      other_user: other_user
    } do
      conn =
        conn
        |> post("/people/#{other_user.id}/change_email", %{"email" => "new@example.com"})

      assert redirected_to(conn, 302) == "/people/#{other_user.id}"
      assert get_flash(conn, :error) == "You can not update this user's email."
    end

    test "user on their own page => successfully changes email", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> post("/people/#{user.id}/change_email", %{"email" => "new@example.com"})

      assert redirected_to(conn, 302) == "/people/#{user.id}"
      assert get_flash(conn, :notice) == "Updated email"
    end

    test "user on their own page with invalid email format", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> post("/people/#{user.id}/change_email", %{"email" => "invalid-email"})

      assert redirected_to(conn, 302) == "/people/#{user.id}"
      assert get_flash(conn, :alert) == "Please enter a valid email address."
    end

    test "user on their own page with empty email", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> post("/people/#{user.id}/change_email", %{"email" => ""})

      assert redirected_to(conn, 302) == "/people/#{user.id}"
      assert get_flash(conn, :alert) == "Email address cannot be empty."
    end

    test "user on their own page with backend error", %{
      conn: conn,
      user: user
    } do
      # Setup stub to return error
      GrpcMock.stub(GuardMock, :change_email, fn %{user_id: "fail"}, _ ->
        {:error, %GRPC.RPCError{message: "Email change failed"}}
      end)

      conn =
        conn
        |> post("/people/#{user.id}/change_email", %{"email" => "new@example.com"})

      assert redirected_to(conn, 302) == "/people/#{user.id}"
      assert get_flash(conn, :alert) =~ "Failed to update email:"
    end

    test "user trying to change non-member email => returns 404", %{
      conn: conn,
      non_member: non_member
    } do
      conn =
        conn
        |> post("/people/#{non_member.id}/change_email", %{"email" => "new@example.com"})

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "POST update_repo_scope" do
    test "when the user can't access the org => returns 404", %{
      conn: conn,
      organization: organization,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      conn =
        conn
        |> post("/people/#{other_user.id}/update_repo_scope/github")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is a memeber, but can't manage people => returns 404", %{
      conn: conn,
      organization: organization,
      user: user,
      other_user: other_user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.add_permissions(organization.id, other_user.id, ["organization.view"])

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> post("/people/#{other_user.id}/update_repo_scope/github")

      assert html_response(conn, 404) =~ "404"
    end

    test "user with manage people permission => returns 404", %{
      conn: conn,
      other_user: other_user
    } do
      conn =
        conn
        |> post("/people/#{other_user.id}/update_repo_scope/github")

      assert html_response(conn, 404) =~ "404"
    end

    test "user on it's own page => allow update", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> post("/people/#{user.id}/update_repo_scope/github")

      assert html_response(conn, 302) =~
               "https://id.semaphoretest.test/oauth/github?scope=repo,user:email&amp;redirect_path=https://.semaphoretest.test/people/#{user.id}"
    end

    test "user with manage people permission updating non member => returns 404", %{
      conn: conn,
      non_member: non_member
    } do
      conn =
        conn
        |> post("/people/#{non_member.id}/update_repo_scope/github")

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "GET organization" do
    test "when the user can manage people => shows the options", %{conn: conn} do
      conn =
        conn
        |> get("/people")

      assert html_response(conn, 200) =~ "id=\"add-people\""
      refute html_response(conn, 200) =~ "Sorry"
    end

    test "when the user can't access the org => returns 404", %{conn: conn} do
      PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get("/people")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is a memeber, but can't manage people => shows note", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> get("/people")

      refute html_response(conn, 200) =~ "Change role"
    end
  end

  describe "POST create_member" do
    test "when the user is not authorized to add a member => returns 404", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> post("/people/create_member")

      assert html_response(conn, 404) =~ "404"
      assert get_flash(conn, :alert) == nil
    end

    test "when the feature is disabled => return 404", %{
      conn: conn,
      organization: organization
    } do
      Support.Stubs.Feature.disable_feature(organization.id, :email_members)

      conn =
        conn
        |> post("/people/create_member")

      Support.Stubs.Feature.enable_feature(organization.id, :email_members)

      assert html_response(conn, 404) =~ "404"
      assert get_flash(conn, :alert) == nil
    end

    test "when operation failed => redirect and put flash message", %{conn: conn} do
      conn =
        conn
        |> post("/people/create_member", email: "foo@example.com", name: "fail")

      assert get_flash(conn, :alert) == "Failed to create member"
      assert html_response(conn, 302) =~ "/people/sync"
    end

    test "when operation succed with password => put flash message and render password", %{
      conn: conn
    } do
      conn =
        conn
        |> post("/people/create_member", email: "foo@example.com", name: "John")

      assert html_response(conn, 200) =~ "User added to the organization"
      assert html_response(conn, 200) =~ "Temporary Password"
    end

    test "when operation succed without password => put flash message and do not render password",
         %{conn: conn} do
      conn =
        conn
        |> post("/people/create_member", email: "foo@example.com", name: "existing")

      assert html_response(conn, 200) =~ "User is already a member"
      refute html_response(conn, 200) =~ "Temporary Password"
    end
  end

  describe "POST invite" do
    test "when the user is not authorized to add a member => returns 404", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      conn =
        conn
        |> post("/people", usernames: ["octocat"])

      assert html_response(conn, 404) =~ "404"
      assert get_flash(conn, :alert) == nil
    end

    test "when the redirect path is set by the caller => redirects there with flash", %{
      conn: conn
    } do
      conn =
        conn
        |> post("/people", github_handle: "octocat", redirect_to: "/some_path")

      assert redirected_to(conn) == "/some_path"
    end

    test "when user is added to organization, and AddMember response includes screen_name, but doesn't include github_username, it shows notification with their screen_name",
         %{conn: conn, organization: organization} do
      conn =
        conn
        |> post("/people", github_handle: "example_screen_name")

      assert get_flash(conn, :notice) ==
               "Neat! example_screen_name is now member of #{organization.api_model.org_username}!"
    end
  end

  describe "GET project" do
    test "when the project is not found => it returns 404", %{conn: conn} do
      conn =
        conn
        |> get("/projects/78114608-be8a-465a-b9cd-81970fb802c7/people")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is not authorized to view members => it returns 404", %{
      conn: conn,
      organization: organization,
      user: user,
      project: project
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(organization.id, user.id, "project.access.view")

      conn =
        conn
        |> get("/projects/#{project.id}/people")

      assert html_response(conn, 200) =~ "Sorry, you can’t access Project People page."
    end
  end

  describe "assign_role/retract_role" do
    test "User who isn't an Owner cant demote another owner", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.change_owner"
      )

      current_owner = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()

      # Indirectly assigning this user an owner role
      PermissionPatrol.add_permissions(organization.id, current_owner, ["organization.delete"])

      assign_conn =
        conn
        |> post("/people/assign_role", %{user_id: current_owner, role_id: role_id})

      assert html_response(assign_conn, 404) =~ "404"

      retract_conn =
        conn
        |> post("/people/retract_role", %{user_id: current_owner})

      assert html_response(retract_conn, 404) =~ "404"
    end

    test "If user is owner, his role can be changed within a project", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      with_mock Front.Models.Member, destroy: fn _, _ -> {:ok, true} end do
        PermissionPatrol.remove_all_permissions()

        PermissionPatrol.allow_everything_except(
          organization.id,
          user.id,
          "organization.change_owner"
        )

        current_owner = Ecto.UUID.generate()
        role_id = DB.first(:rbac_roles) |> Map.get(:id)
        project = Project.create(organization, user)

        # Indirectly assigning this user an owner role
        PermissionPatrol.add_permissions(organization.id, current_owner, ["organization.delete"])

        assign_conn =
          conn
          |> post("/people/assign_role", %{
            user_id: current_owner,
            role_id: role_id,
            project_id: project.id
          })

        assert html_response(assign_conn, 302) =~ "/people"
        refute get_flash(assign_conn, :alert)

        retract_conn =
          conn
          |> post("/people/retract_role", %{
            user_id: current_owner,
            project_id: project.id
          })

        assert html_response(retract_conn, 302) =~ "/people"
        refute get_flash(retract_conn, :alert)
        # This method should be called only when org role is removed, not project role
        assert_not_called(Front.Models.Member.destroy(:_, :_))
      end
    end

    test "Changing organization level role", %{
      conn: conn,
      organization: _organization
    } do
      with_mock Front.Models.Member, destroy: fn _, _ -> {:ok, true} end do
        user_id = Ecto.UUID.generate()
        role_id = DB.first(:rbac_roles) |> Map.get(:id)

        assign_conn =
          conn
          |> post("/people/assign_role", %{
            user_id: user_id,
            role_id: role_id
          })

        assert html_response(assign_conn, 302) =~ "/people"
        refute get_flash(assign_conn, :alert)

        retract_conn =
          conn
          |> post("/people/retract_role", %{
            user_id: user_id
          })

        assert html_response(retract_conn, 302) =~ "/people"
        refute get_flash(retract_conn, :alert)
        # This method should be called only when org role is removed, not project role
        assert_called_exactly(Front.Models.Member.destroy(:_, :_), 1)
      end
    end

    test "without project.access.manage, project role cant be assigned/retracted", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "project.access.manage"
      )

      assign_conn =
        conn
        |> post("/people/assign_role", %{
          user_id: Ecto.UUID.generate(),
          role_id: Ecto.UUID.generate(),
          project_id: Ecto.UUID.generate()
        })

      assert html_response(assign_conn, 404) =~ "404"

      retract_conn =
        conn
        |> post("/people/retract_role", %{
          user_id: Ecto.UUID.generate(),
          project_id: Ecto.UUID.generate()
        })

      assert html_response(retract_conn, 404) =~ "404"
    end

    test "without organization.people.manage, organization role cant be assigned/retracted", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "organization.people.manage"
      )

      assign_conn =
        conn
        |> post("/people/assign_role", %{
          user_id: Ecto.UUID.generate(),
          role_id: Ecto.UUID.generate()
        })

      assert html_response(assign_conn, 404) =~ "404"

      retract_conn =
        conn
        |> post("/people/retract_role", %{
          user_id: Ecto.UUID.generate()
        })

      assert html_response(retract_conn, 404) =~ "404"
    end
  end
end
