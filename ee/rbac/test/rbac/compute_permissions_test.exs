defmodule Rbac.ComputePermissions.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.ComputePermissions
  alias Rbac.RoleBindingIdentification, as: RBI

  @user_id "27676bb0-dfb4-4635-a02e-d206a7faa8de"
  @user2_id "c6354b95-232c-4046-be34-f9b7ade8d5ac"
  @org1_id "9a531b6e-5608-4df0-8093-a38ceb3f761d"
  @project_id "fe7a4135-f4ee-499e-b09a-d4d072421e0b"

  setup do
    Support.Factories.RbacUser.insert(@user_id)
    Support.Factories.RbacUser.insert(@user2_id)
    {:ok, org_scope} = Support.Factories.Scope.insert("org_scope")
    {:ok, _} = Support.Factories.Scope.insert("project_scope")

    {:ok, role1} = Support.Factories.RbacRole.insert(scope_id: org_scope.id)
    {:ok, permission1} = Support.Factories.Permission.insert(scope_id: org_scope.id)

    {:ok, _} =
      Support.Factories.RolePermissionBinding.insert(
        rbac_role_id: role1.id,
        permission_id: permission1.id
      )

    {:ok, role2} = Support.Factories.RbacRole.insert(scope_id: org_scope.id)
    {:ok, permission2} = Support.Factories.Permission.insert(scope_id: org_scope.id)

    {:ok, _} =
      Support.Factories.RolePermissionBinding.insert(
        rbac_role_id: role2.id,
        permission_id: permission2.id
      )

    {:ok, role3} = Support.Factories.RbacRole.insert(scope_id: org_scope.id)
    {:ok, permission3} = Support.Factories.Permission.insert(scope_id: org_scope.id)

    {:ok, _} =
      Support.Factories.RolePermissionBinding.insert(
        rbac_role_id: role3.id,
        permission_id: permission3.id
      )

    {:ok, role4} = Support.Factories.RbacRole.insert(scope_id: org_scope.id)
    {:ok, permission4} = Support.Factories.Permission.insert(scope_id: org_scope.id)

    {:ok, _} =
      Support.Factories.RolePermissionBinding.insert(
        rbac_role_id: role4.id,
        permission_id: permission4.id
      )

    {:ok,
     %{
       role1: role1,
       permission1: permission1,
       role2: role2,
       permission2: permission2,
       role3: role3,
       permission3: permission3,
       role4: role4,
       permission4: permission4
     }}
  end

  describe "compute_permissions/1 form db" do
    test "when empty RBI is given to the function" do
      {returned_status, _} = ComputePermissions.compute_permissions(%RBI{})
      assert returned_status == :error
    end

    test "whene there is one user with no roles" do
      {:ok, rbi} = RBI.new(user_id: @user_id)
      {returned_status, returned_value} = ComputePermissions.compute_permissions(rbi)

      assert returned_status == :ok
      assert Enum.empty?(returned_value) == true
    end

    test "whene there is one user with one role with one permission", test_setup do
      Support.Factories.SubjectRoleBinding.insert(
        role_id: test_setup.role1.id,
        org_id: @org1_id,
        subject_id: @user_id
      )

      {:ok, rbi} = RBI.new(org_id: @org1_id)
      {:ok, returned_value} = ComputePermissions.compute_permissions(rbi)

      expected_value = [
        %{
          user_id: @user_id,
          org_id: @org1_id,
          project_id: "*",
          permission_names: test_setup.permission1.name
        }
      ]

      assert compare_permission_lists(returned_value, expected_value) == true
    end

    test "whene there is one user with one role that inherits another role", test_setup do
      Support.Factories.RoleInheritance.insert(
        inheriting_role_id: test_setup.role1.id,
        inherited_role_id: test_setup.role2.id
      )

      Support.Factories.SubjectRoleBinding.insert(
        role_id: test_setup.role1.id,
        org_id: @org1_id,
        subject_id: @user_id
      )

      {:ok, rbi} = RBI.new(org_id: @org1_id)

      {:ok, returned_value} = ComputePermissions.compute_permissions(rbi)

      expected_value = [
        %{
          user_id: @user_id,
          org_id: @org1_id,
          project_id: "*",
          permission_names: test_setup.permission1.name <> "," <> test_setup.permission2.name
        }
      ]

      assert compare_permission_lists(returned_value, expected_value) == true
    end

    test "multiple users with groups, inherited roles, and role mappings", test_setup do
      Support.Factories.RoleInheritance.insert(
        inheriting_role_id: test_setup.role1.id,
        inherited_role_id: test_setup.role2.id
      )

      Support.Factories.OrgRoleToProjRoleMappings.insert(
        org_role_id: test_setup.role2.id,
        proj_role_id: test_setup.role3.id
      )

      Support.Factories.SubjectRoleBinding.insert(
        role_id: test_setup.role1.id,
        org_id: @org1_id,
        subject_id: @user_id
      )

      {:ok, group} = Support.Factories.Group.insert()

      Support.Factories.SubjectRoleBinding.insert(
        role_id: test_setup.role4.id,
        org_id: @org1_id,
        project_id: @project_id,
        subject_id: group.id
      )

      Support.Factories.UserGroupBinding.insert(user_id: @user_id, group_id: group.id)

      Support.Factories.SubjectRoleBinding.insert(
        role_id: test_setup.role4.id,
        org_id: @org1_id,
        project_id: @project_id,
        subject_id: @user2_id
      )

      {:ok, rbi} = RBI.new(user_id: @user_id)

      {:ok, returned_value} = ComputePermissions.compute_permissions(rbi)

      expected_value = [
        %{
          user_id: @user_id,
          org_id: @org1_id,
          project_id: "*",
          permission_names:
            test_setup.permission1.name <>
              "," <> test_setup.permission2.name <> "," <> test_setup.permission3.name
        },
        %{
          user_id: @user_id,
          org_id: @org1_id,
          project_id: @project_id,
          permission_names: test_setup.permission4.name
        }
      ]

      assert compare_permission_lists(returned_value, expected_value) == true
    end
  end

  describe "compute_permissions/1 with a scoped role tree" do
    @org2_id "0b3c5a8e-6c55-4a5e-9d8f-0f6b4f0f2b11"
    @project2_id "5d6a4f8c-2b7e-4d2a-8c3b-7a1e9f0c4d22"

    setup test_setup do
      # role1 -> role2 (inheritance), role2 maps to project role role3
      Support.Factories.RoleInheritance.insert(
        inheriting_role_id: test_setup.role1.id,
        inherited_role_id: test_setup.role2.id
      )

      Support.Factories.OrgRoleToProjRoleMappings.insert(
        org_role_id: test_setup.role2.id,
        proj_role_id: test_setup.role3.id
      )

      {:ok, group} = Support.Factories.Group.insert()
      Support.Factories.UserGroupBinding.insert(user_id: @user_id, group_id: group.id)

      bindings = [
        [role_id: test_setup.role1.id, org_id: @org1_id, subject_id: @user_id],
        [role_id: test_setup.role4.id, org_id: @org1_id, subject_id: @user2_id],
        [
          role_id: test_setup.role4.id,
          org_id: @org1_id,
          project_id: @project_id,
          subject_id: group.id
        ],
        [
          role_id: test_setup.role3.id,
          org_id: @org1_id,
          project_id: @project_id,
          subject_id: @user2_id
        ],
        [role_id: test_setup.role4.id, org_id: @org2_id, subject_id: @user_id],
        [
          role_id: test_setup.role1.id,
          org_id: @org2_id,
          project_id: @project2_id,
          subject_id: @user2_id
        ]
      ]

      Enum.each(bindings, &Support.Factories.SubjectRoleBinding.insert/1)

      {:ok, group: group}
    end

    test "matches the unscoped computation for every kind of filter", _ctx do
      all = compute_all()

      rbis = [
        [org_id: @org1_id],
        [org_id: @org2_id],
        [user_id: @user_id],
        [user_id: @user2_id],
        [user_id: @user_id, org_id: @org1_id],
        [user_id: @user2_id, org_id: @org2_id],
        [org_id: @org1_id, project_id: @project_id],
        [org_id: @org2_id, project_id: @project2_id],
        [user_id: @user2_id, org_id: @org1_id, project_id: @project_id],
        [org_id: @org1_id, project_id: :is_nil],
        [org_id: @org1_id, project_id: :is_not_nil]
      ]

      for params <- rbis do
        {:ok, rbi} = RBI.new(params)
        {:ok, scoped} = ComputePermissions.compute_permissions(rbi)

        expected = Enum.filter(all, &row_matches?(&1, params))

        assert expected != [], "fixture produced no rows for #{inspect(params)}"

        assert compare_permission_lists(scoped, expected),
               "scoped result differs for #{inspect(params)}: " <>
                 "#{inspect(scoped)} vs #{inspect(expected)}"
      end
    end

    test "group recompute covers its members like the unscoped computation", ctx do
      expected = Enum.filter(compute_all(), &(&1.user_id == @user_id))

      {:ok, rbi} = RBI.new(user_id: ctx.group.id)
      {:ok, scoped} = ComputePermissions.compute_permissions(rbi)

      assert expected != []
      assert compare_permission_lists(scoped, expected)
    end

    test "org recompute includes inherited and mapped permissions", test_setup do
      {:ok, rbi} = RBI.new(org_id: @org1_id, project_id: :is_nil)
      {:ok, rows} = ComputePermissions.compute_permissions(rbi)

      user_row = Enum.find(rows, &(&1.user_id == @user_id))

      assert user_row.permission_names |> String.split(",") |> Enum.sort() ==
               Enum.sort([
                 test_setup.permission1.name,
                 test_setup.permission2.name,
                 test_setup.permission3.name
               ])
    end

    test "org recompute does not leak bindings from another organization", test_setup do
      {:ok, rbi} = RBI.new(org_id: @org1_id)
      {:ok, rows} = ComputePermissions.compute_permissions(rbi)

      assert Enum.all?(rows, &(&1.org_id == @org1_id))

      user_row = Enum.find(rows, &(&1.user_id == @user_id and &1.project_id == "*"))
      refute test_setup.permission4.name in String.split(user_row.permission_names, ",")
    end

    test "user without bindings in the org gets nothing", _ctx do
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: Ecto.UUID.generate())
      assert {:ok, []} = ComputePermissions.compute_permissions(rbi)
    end
  end

  defp compute_all do
    {:ok, rows} =
      Rbac.Repo.transaction(fn ->
        ComputePermissions.compute_all_permissions() |> Enum.to_list()
      end)

    rows
  end

  defp row_matches?(row, params) do
    Enum.all?(params, fn
      {:user_id, user_id} -> row.user_id == user_id
      {:org_id, org_id} -> row.org_id == org_id
      {:project_id, :is_nil} -> row.project_id == "*"
      {:project_id, :is_not_nil} -> row.project_id != "*"
      {:project_id, project_id} -> row.project_id == project_id
    end)
  end

  # Gets 2 lists of values:
  #
  # list1 - list of rows returned by any function for calculatiog user permissions, where each row is a list in itself
  # list2 - list of expacted rows
  #
  # Function checks if lists have same amount of members, after that it compares them member by member,
  # where it checks if first 3 values in list are same, and if string that represent all permissions are
  # same as well. Since we dont know the order in which those permissions will be (DB does not guarantee order
  # when aggregating values), we have to create list of permissions from that one string and then sort that list
  defp compare_permission_lists(list1, list2) do
    case Enum.count(list1) == Enum.count(list2) do
      false ->
        false

      true ->
        comparisons =
          Enum.zip(
            Enum.sort_by(list1, &{&1.user_id, &1.org_id, &1.project_id}),
            Enum.sort_by(list2, &{&1.user_id, &1.org_id, &1.project_id})
          )
          |> Enum.map(fn {list1_map, list2_map} ->
            Map.equal?(
              Map.take(list1_map, [:user_id, :org_id, :project_id]),
              Map.take(list2_map, [:user_id, :org_id, :project_id])
            ) and
              list1_map[:permission_names] |> String.split(",") |> Enum.sort() ==
                list2_map[:permission_names] |> String.split(",") |> Enum.sort()
          end)

        !Enum.member?(comparisons, false)
    end
  end
end
