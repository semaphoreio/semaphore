defmodule FrontWeb.PeopleController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Async, Auth, Models}
  alias Front.Audit
  alias Front.RBAC.{Members, Permissions, RoleManagement}
  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PutProjectAssigns}

  @old_management_pages ~w(sync refresh create destroy)a
  @all_management_pages @old_management_pages ++ ~w(create_member)a
  @project_actions ~w(project fetch_project_non_members)a
  @person_manage_action ~w(reset_password change_email)a
  @self_manage_action ~w(update reset_token update_repo_scope)a
  @person_action @person_manage_action ++ @self_manage_action ++ ~w(show)a

  plug(FetchPermissions, [scope: "org"] when action in @all_management_pages)

  plug(
    PageAccess,
    [permissions: "organization.people.manage"] when action in @all_management_pages
  )

  plug(FetchPermissions, [scope: "org"] when action in @person_action)
  plug(PageAccess, [permissions: "organization.view"] when action in @person_action)

  plug(FetchPermissions, [scope: "org"] when action in [:organization])
  plug(PageAccess, [permissions: "organization.view"] when action in [:organization])

  plug(
    FetchPermissions,
    [scope: "org"]
    when action in [:update, :reset_token, :change_email, :reset_password, :update_repo_scope]
  )

  plug(PutProjectAssigns when action in @project_actions)
  plug(FetchPermissions, [scope: "project"] when action in @project_actions)
  plug(PageAccess, [permissions: "project.view"] when action in [:project])

  plug(PageAccess, [permissions: "project.access.view"] when action == :fetch_project_non_members)

  plug(
    Header
    when action in [
           :organization,
           :project,
           :show,
           :reset_token,
           :reset_password,
           :change_email,
           :sync,
           :assign_role,
           :create_member
         ]
  )

  plug(FrontWeb.Plugs.CacheControl, :no_cache)

  plug(:validate_person_manage! when action in @person_manage_action)
  plug(:validate_owner! when action in @self_manage_action)
  plug(:ensure_membership! when action in @person_action)

  defp validate_person_manage!(conn, _opts) do
    if conn.assigns.permissions["organization.people.manage"] or
         conn.assigns.user_id == conn.params["user_id"] do
      conn
    else
      render_404(conn)
    end
  end

  defp validate_owner!(conn, _opts) do
    if conn.assigns.user_id == conn.params["user_id"] do
      conn
    else
      render_404(conn)
    end
  end

  defp ensure_membership!(conn, _opts) do
    if Front.RBAC.Permissions.has?(
         conn.params["user_id"],
         conn.assigns.organization_id,
         "organization.view"
       ) do
      conn
    else
      render_404(conn)
    end
  end

  def assign_role(conn, params = %{"format" => "json"}) do
    assign_user_role(conn, params)
    |> case do
      {:ok, %{message: message}} ->
        conn
        |> json(%{message: message})

      {:error, :not_found} ->
        conn
        |> put_status(422)
        |> json(%{})

      {:error, error} ->
        conn
        |> put_status(422)
        |> json(%{message: error})
    end
  end

  def assign_role(conn, params) do
    org_id = conn.assigns.organization_id
    project_id = params["project_id"] || ""

    redirect_to = extrapolate_redirect_page(org_id, project_id)

    assign_user_role(conn, params)
    |> case do
      {:ok, %{message: message}} ->
        conn
        |> put_flash(:notice, message)
        |> redirect_to.()

      {:error, :render_404} ->
        conn
        |> render_404()

      {:error, error} ->
        conn
        |> put_flash(:alert, error)
        |> redirect_to.()
    end
  end

  defp assign_user_role(conn, params) do
    Watchman.benchmark("people.assing_role.duration", fn ->
      org_id = conn.assigns.organization_id
      project_id = params["project_id"] || ""
      user_id = params["user_id"]
      role_id = params["role_id"]
      requester_id = conn.assigns.user_id
      member_type = params["member_type"] || "user"

      conn =
        conn
        |> authorize_people_management(project_id)
        |> is_owner_changed?(role_id, user_id, project_id)

      if conn.halted() do
        {:error, :render_404}
      else
        case RoleManagement.assign_role(
               requester_id,
               org_id,
               user_id,
               role_id,
               project_id,
               member_type
             ) do
          {:ok, _} ->
            log_assign_role(conn, user_id, org_id, role_id, project_id)

            {:ok, %{message: "Role successfully assigned"}}

          {:error, error} ->
            Logger.error("[PeopleController] Error in assign_role function: #{inspect(error)}")

            {:error, "error occurred while assigning the role. Please contact our support team."}
        end
      end
    end)
  end

  defp log_assign_role(conn, user_id, org_id, role_id, project_id) do
    fetch_user = Async.run(fn -> Front.Models.User.find(user_id) end)
    {:ok, roles} = RoleManagement.list_possible_roles(org_id)
    assigned_role = Enum.find(roles, fn role -> role.id == role_id end)
    {:ok, user} = Async.await(fetch_user)

    if user != nil do
      description =
        if project_id == "" do
          "User #{user.name} was assigned #{assigned_role.name} role in the organization"
        else
          project = Front.Models.Project.find(project_id, org_id)

          "User #{user.name} was assigned #{assigned_role.name} role within the #{project.name} project."
        end

      Logger.info(
        "User #{conn.assigns.user_id} assigned #{assigned_role.name} to the #{user.id}. Org id #{inspect(org_id)}, project id #{inspect(project_id)}"
      )

      conn
      |> Audit.new(:User, :Modified)
      |> Audit.add(description: description)
      |> Audit.add(resource_id: user.id)
      |> Audit.metadata(user_id: user.id)
      |> Audit.metadata(user_name: user.name)
      |> Audit.metadata(role_id: role_id)
      |> Audit.metadata(role_name: assigned_role.name)
      |> Audit.log()
    end
  end

  def retract_role(conn, params) do
    Watchman.benchmark("people.retract_role.duration", fn ->
      org_id = conn.assigns.organization_id
      project_id = params["project_id"] || ""
      user_id = params["user_id"]
      requester_id = conn.assigns.user_id

      conn =
        authorize_people_management(conn, project_id)
        |> is_owner_changed?(nil, user_id, project_id)

      if conn.halted() do
        conn
      else
        redirect_to = extrapolate_redirect_page(org_id, project_id)

        case RoleManagement.retract_role(requester_id, org_id, user_id, project_id) do
          {:ok, _} ->
            if project_id == "" do
              Models.Member.destroy(org_id, user_id: user_id)
            end

            log_retract_role(conn, user_id, org_id, project_id)

            conn
            |> put_flash(:notice, "Role has been removed.")
            |> redirect_to.()

          {:error, error} ->
            Logger.error(
              "Failed to remove member. " <>
                "user_id: #{inspect(user_id)}, org_id: #{inspect(org_id)}, project_id: #{inspect(project_id)}. " <>
                "Error: #{inspect(error)}"
            )

            conn
            |> put_flash(
              :alert,
              "An error occurred while removing member, please contact our support team."
            )
            |> redirect_to.()
        end
      end
    end)
  end

  defp log_retract_role(conn, user_id, org_id, project_id) do
    user = Front.Models.User.find(user_id)

    if user != nil do
      description =
        if project_id == "" do
          "User #{user.name} was removed from the organization"
        else
          project = Front.Models.Project.find(project_id, org_id)
          "User #{user.name} was removed from the #{project.name} project."
        end

      Logger.info(
        "User #{conn.assigns.user_id} removed #{user.id}. Org id #{inspect(org_id)}, project id #{inspect(project_id)}"
      )

      conn
      |> Audit.new(:User, :Removed)
      |> Audit.add(description: description)
      |> Audit.add(resource_id: user.id)
      |> Audit.metadata(user_id: user.id)
      |> Audit.metadata(user_name: user.name)
      |> Audit.log()
    end
  end

  @max_people_per_org 2000
  @return_non_members 10
  def fetch_project_non_members(conn, params) do
    org_id = conn.assigns.organization_id
    project = conn.assigns.project
    username = params["name_contains"] || ""
    user_type = params["type"] || ""

    member_role_id =
      if Front.ce?() do
        {:ok, roles} = RoleManagement.list_possible_roles(org_id, "org_scope")

        member_role = Enum.find(roles, fn role -> role.name == "Member" end)
        member_role.id
      else
        ""
      end

    fetch_org_members =
      async_fetch_members(org_id, "",
        username: username,
        page_size: @max_people_per_org,
        member_type: user_type,
        role_id: member_role_id
      )

    fetch_project_members =
      async_fetch_members(org_id, project.id,
        page_size: @max_people_per_org,
        member_type: user_type,
        role_id: member_role_id
      )

    {:ok, {:ok, {org_members, _total_pages}}} = Async.await(fetch_org_members)
    {:ok, {:ok, {project_members, _total_pages}}} = Async.await(fetch_project_members)

    non_members = extrapolate_project_non_members(org_members, project_members)

    conn |> json(non_members |> Enum.take(@return_non_members))
  end

  defp extrapolate_project_non_members(org_members, project_members) do
    project_member_ids = Enum.map(project_members, & &1.id)

    org_members
    |> Enum.filter(fn org_member -> org_member.id not in project_member_ids end)
  end

  @doc """
    Returns an HTML `<div>` containing a list of organization or project members. This will later be embedded
    in the people page via JavaScript.

    It accepts three query parameters:
      - `project_id`:     If provided, the function will render project members. If omitted, the function will
                          display organization members.
      - `page_no`:        Specifies the page number.
      - `name_contains`:  If provided, the function will filter members based on their name, using the value
                          passed via this parameter.
      - `member_type`:    If provided, filters members based on their type (user or group).
  """
  def render_members(conn, params) do
    Watchman.benchmark("filtered_org_members.duration", fn ->
      org_id = conn.assigns.organization_id
      project_id = params["project_id"] || ""
      page_no = (params["page_no"] || "0") |> String.to_integer()
      username = params["name_contains"] || ""
      role_id = params["members_with_role"] || ""

      fetch_roles =
        Async.run(fn ->
          RoleManagement.list_possible_roles(org_id, extrapolate_scope(project_id))
        end)

      fetch_groups =
        async_fetch_members(org_id, project_id,
          username: username,
          role_id: role_id,
          page_no: page_no,
          member_type: "group"
        )

      fetch_members =
        async_fetch_members(org_id, project_id,
          username: username,
          role_id: role_id,
          page_no: page_no,
          member_type: "user"
        )

      conn = conn |> assign_permissions(project_id)
      {:ok, {:ok, {members, total_pages}}} = Async.await(fetch_members)
      {:ok, {:ok, {groups, _total_pages}}} = Async.await(fetch_groups)
      {:ok, {:ok, all_roles}} = Async.await(fetch_roles)

      conn
      |> put_layout(false)
      |> put_resp_header("total_pages", Integer.to_string(total_pages))
      |> render("members/members_list.html",
        members: members,
        groups: groups,
        roles: all_roles,
        groups: groups,
        org_scope?: project_id == "",
        org_id: org_id,
        permissions: conn.assigns.permissions
      )
    end)
  rescue
    error ->
      org_id = conn.assigns.organization_id
      project_id = params["project_id"] || ""

      Logger.error(
        "[PeopleController] Error in filter_members function (Org_id: #{inspect(org_id)}, project_id: #{inspect(project_id)}): #{inspect(error)}."
      )

      conn
      |> put_status(500)
      |> send_resp(:internal_server_error, "Error while filtering members")
  end

  ###
  ### Helper functions for filtering org/project members
  ###

  defp async_fetch_members(org_id, _project_id = "", opts) do
    Async.run(fn ->
      Members.list_org_members(org_id, opts)
    end)
  end

  defp async_fetch_members(org_id, project_id, opts) do
    Async.run(fn ->
      Members.list_project_members(org_id, project_id, opts)
    end)
  end

  defp assign_permissions(conn, _project_id = ""), do: FetchPermissions.call(conn, scope: "org")

  defp assign_permissions(conn, project_id) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    has_permissions =
      Front.RBAC.Permissions.has?(user_id, org_id, project_id, [
        "project.access.view",
        "project.access.manage"
      ])

    Plug.Conn.assign(conn, :permissions, has_permissions)
  end

  defp extrapolate_scope(_project_id = ""), do: "org_scope"
  defp extrapolate_scope(_project_id), do: "project_scope"

  defp extrapolate_redirect_page(_org_id, _project_id = "") do
    fn conn -> conn |> redirect(to: people_path(conn, :organization)) end
  end

  defp extrapolate_redirect_page(org_id, project_id) do
    fn conn ->
      project = Models.Project.find(project_id, org_id)

      conn
      |> redirect(to: people_path(conn, :project, project.name))
    end
  end

  ### -------------------------------------------------

  def create_member(conn, params = %{"format" => "json"}) do
    create_email_member(conn, params)
    |> case do
      {:ok, %{password: password, message: message}} ->
        conn
        |> json(%{
          password: password,
          message: message
        })

      {:error, :render_404} ->
        conn
        |> put_status(404)
        |> json(%{message: "not found"})

      {:error, error_msg} ->
        conn
        |> put_status(422)
        |> json(%{message: error_msg})
    end
  end

  def create_member(conn, params) do
    create_email_member(conn, params)
    |> case do
      {:ok, %{password: password, message: message}} ->
        org_id = conn.assigns.organization_id
        {:ok, collaborators} = Models.Member.repository_collaborators(org_id)
        layout = {FrontWeb.LayoutView, "organization.html"}

        render(
          conn,
          "collaborators.html",
          js: "people_member_new",
          collaborators: collaborators,
          redirect_path: people_path(conn, :organization),
          password: password,
          error: nil,
          alert: nil,
          notice: message,
          layout: layout
        )

      {:error, :render_404} ->
        conn
        |> render_404()

      {:error, error_msg} ->
        conn
        |> put_flash(:alert, error_msg)
        |> redirect(to: people_path(conn, :sync))
    end
  end

  defp create_email_member(conn, params) do
    Watchman.benchmark("people.create_member", fn ->
      if email_members_supported?(conn.assigns.organization_id) || Front.ce?() do
        user_id = conn.assigns.user_id
        org_id = conn.assigns.organization_id

        email = params["email"]
        name = params["name"]

        conn
        |> Audit.new(:User, :Added)
        |> Audit.add(description: "Adding members to the organization")
        |> Audit.add(resource_name: email)
        |> Audit.metadata(name: name)
        |> Audit.log()

        case Models.Member.create(email, name, org_id, user_id) do
          {:ok, response} ->
            {:ok, %{password: response.password, message: response.msg}}

          {:error, error_msg} ->
            {:error, error_msg}
        end
      else
        {:error, :render_404}
      end
    end)
  end

  def create(conn, params = %{"format" => "json"}) do
    org_id = conn.assigns.organization_id
    {provider, username} = parse_provider_and_username(params, org_id)

    invitees =
      case username do
        nil ->
          params["invitees"] || []

        username ->
          [
            %{
              "uid" => "",
              "username" => username,
              "invite_email" => "",
              "provider" => provider
            }
          ]
      end

    invite_collaborators(conn, invitees)
    |> case do
      {:ok, %{message: message}} ->
        conn
        |> json(%{message: message})

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{message: message})
    end
  end

  def create(conn, params) do
    org_id = conn.assigns.organization_id

    members =
      (params["people"] || [])
      |> Enum.map(fn username ->
        params[username]
      end)
      |> Enum.filter(& &1)

    {provider, username} = parse_provider_and_username(params, org_id)

    invitees =
      case username do
        nil ->
          members

        username ->
          [
            %{
              "uid" => "",
              "username" => username,
              "invite_email" => "",
              "provider" => provider
            }
          ]
      end

    invite_collaborators(conn, invitees)
    |> case do
      {:ok, %{message: message}} ->
        conn
        |> put_flash(:notice, message)
        |> redirect(to: after_create_redirect_path(conn, params["redirect_to"]))

      {:error, message} ->
        conn
        |> put_flash(:alert, URI.decode(message))
        |> redirect(to: people_path(conn, :sync))
    end
  end

  defp invite_collaborators(conn, invitees) do
    Watchman.benchmark("people.add.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      conn
      |> Audit.new(:User, :Added)
      |> Audit.add(description: "Adding members to the organization")
      |> Audit.add(resource_name: inspect(invitees))
      |> Audit.log()

      case Models.Member.invite(invitees, org_id, user_id) do
        {:ok, members} ->
          org = Models.Organization.find(org_id)
          notice_copy = compose_create_members_copy(members, invitees, org)
          {:ok, %{message: notice_copy}}

        {:error, error_msg} ->
          Logger.error("[People controller] Error while adding new members #{inspect(error_msg)}")
          {:error, error_msg}
      end
    end)
  end

  def destroy(conn, %{"membership_id" => membership_id}) do
    Watchman.benchmark("people.remove.duration", fn ->
      org_id = conn.assigns.organization_id

      conn
      |> Audit.new(:User, :Removed)
      |> Audit.add(description: "Removing members in the organization")
      |> Audit.add(resource_id: membership_id)
      |> Audit.log()

      case Models.Member.destroy(org_id, membership_id: membership_id) do
        {:ok, _} ->
          conn
          |> put_flash(:notice, "Member has been removed.")
          |> redirect(to: people_path(conn, :organization))

        {:error, error} ->
          conn
          |> put_flash(:alert, error)
          |> redirect(to: people_path(conn, :organization))
      end
    end)
  end

  def project(conn, _params) do
    Watchman.benchmark("project_people.show.duration", fn ->
      notice = conn |> get_flash(:notice)
      alert = conn |> get_flash(:alert)

      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project = conn.assigns.project

      fetch_members = Async.run(fn -> Members.list_project_members(org_id, project.id) end)

      fetch_groups =
        Async.run(fn -> Members.list_project_members(org_id, project.id, member_type: "group") end)

      fetch_service_accounts =
        async_fetch_members(org_id, project.id, member_type: "service_account")

      fetch_is_project_starred? =
        Async.run(fn -> Models.User.has_favorite(user_id, org_id, project.id) end)

      fetch_roles =
        Async.run(fn -> RoleManagement.list_possible_roles(org_id, "project_scope") end)

      {:ok, {:ok, all_roles}} = Async.await(fetch_roles)
      {:ok, {:ok, {members, total_pages}}} = Async.await(fetch_members)
      {:ok, {:ok, {groups, _}}} = Async.await(fetch_groups)
      {:ok, is_project_starred?} = Async.await(fetch_is_project_starred?)
      {:ok, {:ok, {service_accounts, _total_pages}}} = Async.await(fetch_service_accounts)

      assigns =
        %{
          notice: notice,
          pagination: %{page_no: 0, total_pages: total_pages},
          alert: alert,
          roles: all_roles,
          permissions: conn.assigns.permissions,
          members: members,
          groups: groups,
          service_accounts: service_accounts,
          project_id: project.id,
          title: "People・#{project.name}",
          org_scope?: false,
          org_id: org_id,
          starred?: is_project_starred?,
          js: :people_page,
          layout: {FrontWeb.LayoutView, "project.html"},
          redirect_path: people_path(conn, :project, project.name)
        }
        |> Front.Breadcrumbs.Project.construct(conn, :people)

      render(conn, "project.html", assigns)
    end)
  end

  def show(conn, params = %{"user_id" => user_id}) do
    Watchman.benchmark("people.show", fn ->
      render_show(conn, user_id, params["errors"])
    end)
  end

  def update(conn, params = %{"user_id" => user_id}) do
    Watchman.benchmark("people.update", fn ->
      fetch_user = Async.run(fn -> Models.User.find_user_with_providers(user_id) end)
      {:ok, user} = Async.await(fetch_user)

      case Models.User.update(user, %{name: params["name"]}) do
        {:ok, _updated_user} ->
          conn
          |> put_flash(:notice, "Changes saved.")
          |> redirect(to: people_path(conn, :show, user_id))

        {:error, error_messages} ->
          user = Map.put(user, :name, params["name"])

          conn
          |> put_flash(:alert, compose_alert_message(error_messages.errors))
          |> put_status(422)
          |> render_show(user, error_messages)
      end
    end)
  end

  defp parse_provider_and_username(params, org_id) do
    gitlab_enabled = FeatureProvider.feature_enabled?(:gitlab, param: org_id)

    case params do
      %{"github_handle" => username} when username != nil ->
        {"github", username}

      %{"gitlab_handle" => username} when username != nil and gitlab_enabled ->
        {"gitlab", username}

      _ ->
        {"", nil}
    end
  end

  defp compose_alert_message(%{other: m}), do: "Failed: #{m}"
  defp compose_alert_message(_), do: "Failed to update the account..."

  def reset_token(conn, %{"user_id" => user_id}) do
    Watchman.benchmark("people.reset_token", fn ->
      conn
      |> Audit.new(:User, :Modified)
      |> Audit.add(description: "Reset Token")
      |> Audit.add(resource_id: user_id)
      |> Audit.log()

      case Models.User.regenerate_token(user_id) do
        {:ok, new_token} ->
          conn
          |> put_flash(:notice, "Token reset.")
          |> assign(:token, new_token)
          |> render_show(user_id)

        {:error, error} ->
          Logger.error("Error during token reset #{user_id}: #{inspect(error)}")

          conn
          |> put_flash(
            :alert,
            "An error occurred while rotating the API token. Please contact our support team."
          )
          |> redirect(to: people_path(conn, :show, user_id))
      end
    end)
  end

  def change_email(conn, params = %{"user_id" => user_id, "format" => "json"}) do
    change_user_email(conn, user_id, params["email"])
    |> case do
      {:ok, %{message: message}} ->
        conn
        |> json(%{message: message})

      {:error, :render_404} ->
        conn
        |> put_status(404)
        |> json(%{message: "not found"})

      {:error, error_msg} ->
        conn
        |> put_status(422)
        |> json(%{message: error_msg})
    end
  end

  defp change_user_email(conn, user_id, email) do
    Watchman.benchmark("people.change_email", fn ->
      if email_members_supported?(conn.assigns.organization_id) || Front.ce?() do
        conn
        |> Audit.new(:User, :Modified)
        |> Audit.add(description: "Change Email")
        |> Audit.add(resource_id: user_id)
        |> Audit.log()

        Models.Member.change_email(conn.assigns.user_id, user_id, email)
        |> case do
          {:ok, %{msg: msg}} ->
            {:ok, %{message: msg}}

          {:error, error_msg} ->
            {:error, error_msg}
        end
      else
        {:error, :render_404}
      end
    end)
  end

  def reset_password(conn, %{"user_id" => user_id, "format" => "json"}) do
    reset_user_password(conn, user_id)
    |> case do
      {:ok, res} ->
        conn
        |> json(%{
          message: res.message,
          password: res.password
        })

      {:error, :render_404} ->
        conn
        |> put_status(404)
        |> json(%{message: "not found"})

      {:error, error_message} ->
        conn
        |> put_status(422)
        |> json(%{
          message: error_message
        })
    end
  end

  def reset_password(conn, %{"user_id" => user_id}) do
    reset_user_password(conn, user_id)
    |> case do
      {:ok, res} ->
        conn
        |> put_flash(:notice, res.message)
        |> assign(:password, res.password)
        |> render_show(user_id)

      {:error, :render_404} ->
        conn
        |> render_404()

      {:error, error_message} ->
        conn
        |> put_flash(:alert, error_message)
        |> redirect(to: people_path(conn, :show, user_id))
    end
  end

  defp reset_user_password(conn, user_id) do
    Watchman.benchmark("people.reset_password", fn ->
      if email_members_supported?(conn.assigns.organization_id) || Front.ce?() do
        conn
        |> Audit.new(:User, :Modified)
        |> Audit.add(description: "Reset Password")
        |> Audit.add(resource_id: user_id)
        |> Audit.log()

        Models.Member.reset_password(conn.assigns.user_id, user_id)
        |> case do
          {:ok, result} ->
            {:ok,
             %{
               password: result.password,
               message: result.msg
             }}

          {:error, error} ->
            Logger.error("Error during password reset #{user_id}: #{inspect(error)}")

            {:error,
             "An error occurred while rotating the password. Please contact our support team."}
        end
      else
        {:error, :render_404}
      end
    end)
  end

  def update_repo_scope(conn, params = %{"user_id" => user_id, "provider" => provider}) do
    Watchman.benchmark("people.update_repo_scope", fn ->
      scope =
        case params["access_level"] do
          "public" -> "public_repo,user:email"
          "private" -> "repo,user:email"
          "email" -> "user:email"
          _ -> "repo,user:email"
        end

      conn
      |> Audit.new(:User, :Modified)
      |> Audit.add(description: "Update repository scope")
      |> Audit.add(resource_id: user_id)
      |> Audit.metadata(provider: provider)
      |> Audit.metadata(scope: scope)
      |> Audit.log()

      org_name = conn.assigns.organization_username

      domain = Application.get_env(:front, :domain)
      path = "https://#{org_name}.#{domain}#{people_path(conn, :show, user_id)}"

      url =
        case provider do
          "github" ->
            "https://id.#{domain}/oauth/github?scope=#{scope}&redirect_path=#{path}"

          p ->
            "https://id.#{domain}/oauth/#{p}?redirect_path=#{path}"
        end

      redirect(conn, external: url)
    end)
  end

  defp render_show(conn, user_id, errors \\ nil)

  defp render_show(conn, user_id, errors) when is_binary(user_id) do
    fetch_user = Async.run(fn -> Models.User.find_user_with_providers(user_id) end)
    {:ok, user} = Async.await(fetch_user)

    render_show(conn, user, errors)
  end

  defp render_show(conn, user, errors) do
    render(
      conn,
      "show.html",
      js: "people_show",
      user: user,
      owned: user.id == conn.assigns.user_id,
      errors: errors,
      title: "Semaphore - Account"
    )
  end

  ### -------------------------------------------------

  def refresh(conn, _params) do
    Watchman.benchmark("people.refresh_organization.duration", fn ->
      Auth.refresh_people(conn.assigns.organization_id)

      conn
      |> json(%{
        message: "Sync with repository triggered successfully"
      })
    end)
  end

  def organization(conn, _params) do
    Watchman.benchmark("people.organization.duration", fn ->
      notice = get_flash(conn, :notice)
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_org =
        Async.run(fn -> Models.Organization.find(org_id) end,
          metric: "people_page.api.organization.describe"
        )

      {:ok, organization} = Async.await(fetch_org)

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)
      fetch_members = Async.run(fn -> Members.list_org_members(org_id) end)
      fetch_groups = Async.run(fn -> Members.list_org_members(org_id, member_type: "group") end)
      fetch_roles = Async.run(fn -> RoleManagement.list_possible_roles(org_id, "org_scope") end)
      invitation_metric = "people_page.api.organization.invitations"

      fetch_invitations =
        Async.run(fn -> Models.Member.invitations(org_id) end, metric: invitation_metric)

      {:ok, user} = Async.await(fetch_user)
      {:ok, {:ok, {members, total_pages}}} = Async.await(fetch_members)
      {:ok, {:ok, {groups, _}}} = Async.await(fetch_groups)
      {:ok, {:ok, invitations}} = Async.await(fetch_invitations)
      {:ok, {:ok, all_roles}} = Async.await(fetch_roles)

      render(
        conn,
        "organization.html",
        permissions: conn.assigns.permissions,
        js: :people_page,
        pagination: %{page_no: 0, total_pages: total_pages},
        roles: all_roles,
        user: user,
        organization: organization,
        notice: notice,
        members: members,
        groups: groups,
        invitations: invitations,
        org_scope?: true,
        org_id: org_id,
        title: "People・#{organization.name}",
        redirect_path: people_path(conn, :organization),
        layout: {FrontWeb.LayoutView, "organization.html"}
      )
    end)
  end

  def sync(conn, %{"format" => "json"}) do
    Watchman.benchmark("sync.organization.duration", fn ->
      org_id = conn.assigns.organization_id

      Models.Member.repository_collaborators(org_id)
      |> case do
        {:ok, collaborators} ->
          conn
          |> render("sync.json", collaborators: collaborators)

        _ ->
          conn
          |> put_status(500)
          |> json(%{message: "Internal error occurred"})
      end
    end)
  end

  def sync(conn, params) do
    Watchman.benchmark("sync.organization.duration", fn ->
      org_id = conn.assigns.organization_id

      error = conn |> get_flash(:error)
      alert = conn |> get_flash(:alert)

      layout =
        if params["layout"] == "false",
          do: false,
          else: {FrontWeb.LayoutView, "organization.html"}

      {:ok, collaborators} = Models.Member.repository_collaborators(org_id)

      render(
        conn,
        "collaborators.html",
        js: "people_sync",
        collaborators: collaborators,
        redirect_path: people_path(conn, :organization),
        password: "",
        error: error,
        alert: alert,
        layout: layout
      )
    end)
  end

  ###
  ### Helper functions
  ###

  defp authorize_people_management(conn, project_id) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    can_manage? =
      if project_id == "" do
        Permissions.has?(user_id, org_id, "organization.people.manage")
      else
        Permissions.has?(user_id, org_id, project_id, "project.access.manage")
      end

    if can_manage?, do: conn, else: render_404(conn)
  end

  # If user want's to promote someone to owner, or demote current owner,
  # they need a special permission. If they are changing owner role within a project,
  # that is fine
  defp is_owner_changed?(conn, _role_id, _subject_id, project_id) when project_id != "", do: conn

  defp is_owner_changed?(conn, role_id, subject_id, _project_id) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    fetch_selected_role =
      Async.run(fn ->
        {:ok, roles} = RoleManagement.list_possible_roles(org_id, "org_scope")
        roles |> Enum.find(%{name: ""}, &(&1.id == role_id))
      end)

    fetch_is_currently_owner =
      Async.run(fn -> Permissions.has?(subject_id, org_id, "organization.delete") end)

    {:ok, selected_role} = Async.await(fetch_selected_role)
    {:ok, is_currently_owner?} = Async.await(fetch_is_currently_owner)

    if selected_role.name == "Owner" || is_currently_owner? do
      can_change_owner? = Permissions.has?(user_id, org_id, "organization.change_owner")

      if can_change_owner?, do: conn, else: render_404(conn)
    else
      conn
    end
  end

  defp render_404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end

  defp after_create_redirect_path(conn, redirect_path) do
    if redirect_path, do: redirect_path, else: conn.request_path
  end

  defp compose_create_members_copy(members, names, organization) do
    created_usernames = MapSet.new(members, & &1.provider.login)
    requested_usernames = MapSet.new(names, & &1["username"])
    existing_usernames = MapSet.difference(requested_usernames, created_usernames)

    created_users_notice =
      compose_created_users_notice(Enum.to_list(created_usernames), organization)

    existing_users_notice =
      compose_existing_users_notice(Enum.to_list(existing_usernames), organization)

    "Neat!#{created_users_notice}#{existing_users_notice}"
  end

  defp compose_created_users_notice([], _organization), do: ""

  defp compose_created_users_notice([username], organization),
    do: " #{username} is now member of #{organization.username}!"

  defp compose_created_users_notice(usernames, organization),
    do: " #{Enum.join(usernames, ", ")} are now members of #{organization.username}!"

  defp compose_existing_users_notice([], _organization), do: ""

  defp compose_existing_users_notice([username], organization),
    do: " #{username} was already a member of #{organization.username}."

  defp compose_existing_users_notice(usernames, organization),
    do: " #{Enum.join(usernames, ", ")} were already members of #{organization.username}."

  @spec email_members_supported?(organization_id :: String.t()) :: bool
  defp email_members_supported?(organization_id),
    do: FeatureProvider.feature_enabled?(:email_members, param: organization_id)
end
