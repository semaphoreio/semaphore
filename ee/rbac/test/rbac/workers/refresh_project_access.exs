defmodule Rbac.Workers.RefreshProjectAccessTest do
  use Rbac.RepoCase, async: false

  alias Rbac.Worker.RefresProjectAccess, as: Worker
  alias Support.Factories.RbacRefreshProjectAccessRequest, as: Request
  import Ecto.Query, only: [where: 3]
  import Mock

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()

  setup do
    Support.Factories.Scope.insert("org_scope")
    {:ok, project_scope} = Support.Factories.Scope.insert("project_scope")
    Support.Factories.RbacUser.insert(@user_id)

    {:ok, worker} = Worker.start_link()
    on_exit(fn -> Process.exit(worker, :kill) end)

    {:ok, %{project_scope_id: project_scope.id}}
  end

  describe "processing single refresh request" do
    test "one new collaborator who is not part of org" do
      Request.insert(projects: [[action: :add]])
      work()

      assert_no_of_finished_requests(1)
      assert_no_project_roles_assigned(@user_id, @org_id, 0)
    end

    test "one new collaborator who is part of org" do
      add_user_to_org(@user_id, @org_id)
      Request.insert(user_id: @user_id, org_id: @org_id, projects: [[action: :add]])
      work()
      assert_no_of_finished_requests(1)
      assert_no_project_roles_assigned(@user_id, @org_id, 1)
    end

    test "one collaborator removed", state do
      # test setup
      add_user_to_org(@user_id, @org_id)

      {:ok, role} =
        Support.Factories.RbacRole.insert(org_id: @org_id, scope_id: state[:project_scope_id])

      Support.Factories.RolePermissionBinding.insert(rbac_role_id: role.id)

      {:ok, rbi} =
        Rbac.RoleBindingIdentification.new(
          user_id: @user_id,
          org_id: @org_id,
          project_id: @project_id
        )

      Rbac.RoleManagement.assign_role(rbi, role.id, :github)
      assert_no_project_roles_assigned(@user_id, @org_id, 1)

      Request.insert(
        user_id: @user_id,
        org_id: @org_id,
        projects: [[id: @project_id, action: :remove]]
      )

      work()
      assert_no_of_finished_requests(1)
      assert_no_project_roles_assigned(@user_id, @org_id, 0)
    end

    test "user added to 2 projects" do
      add_user_to_org(@user_id, @org_id)

      Request.insert(
        user_id: @user_id,
        org_id: @org_id,
        projects: [[action: :add], [action: :add]]
      )

      work()
      assert_no_of_finished_requests(1)
      assert_no_project_roles_assigned(@user_id, @org_id, 2)
    end

    test "when processing fails" do
      add_user_to_org(@user_id, @org_id)
      Request.insert(user_id: @user_id, org_id: @org_id, projects: [[action: :add]])

      with_mock Rbac.Store.ProjectAccess, add_project_access: fn _ -> throw("Exception") end do
        work()
      end

      assert_no_of_finished_requests(0)
      assert_no_project_roles_assigned(@user_id, @org_id, 0)
    end
  end

  defp assert_no_of_finished_requests(no) do
    assert Rbac.Repo.RbacRefreshProjectAccessRequest
           |> where([r], r.state == ^"done")
           |> Rbac.Repo.aggregate(:count, :id) == no
  end

  defp assert_no_project_roles_assigned(user_id, org_id, no) do
    assert Rbac.Repo.SubjectRoleBinding
           |> where([srb], not is_nil(srb.project_id))
           |> Rbac.Repo.aggregate(:count, :id) == no

    assert Rbac.Store.ProjectAccess.get_list_of_projects(user_id, org_id) |> length() == no
    assert Rbac.Repo.UserPermissionsKeyValueStore |> Rbac.Repo.aggregate(:count, :key) == no
  end

  defp add_user_to_org(user_id, org_id) do
    Support.Factories.SubjectRoleBinding.insert(org_id: org_id, subject_id: user_id)
  end

  defp work do
    Worker.perform_now()
    :timer.sleep(500)
  end
end
