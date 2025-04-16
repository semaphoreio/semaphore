defmodule Rbac.Okta.Saml.Provisioner.AddUser.Test do
  use Rbac.RepoCase, async: true
  alias Rbac.Okta.Saml.JitProvisioner.AddUser
  alias Rbac.{Repo, FrontRepo}
  alias Support.Factories

  @org_id Ecto.UUID.generate()

  setup do
    Support.Rbac.create_org_roles(@org_id)

    {:ok, jit_user} = Support.Factories.SamlJitUser.insert(org_id: @org_id)
    {:ok, %{jit_user: jit_user}}
  end

  describe "createing user based on the saml_jit request" do
    test "When the org has no custom mapping created", ctx do
      {:ok, jit_user} = AddUser.run(ctx.jit_user)

      assert_user_created(jit_user)
      assert_role_assigned(jit_user, "Member")
    end

    test "When the org has custom mapping but w/o any role mappings", ctx do
      {:ok, role} = Repo.RbacRole.get_role_by_name("Admin", "org_scope", ctx.jit_user.org_id)

      Factories.IdpGroupMapping.insert(
        organization_id: ctx.jit_user.org_id,
        default_role_id: role.id
      )

      {:ok, jit_user} = AddUser.run(ctx.jit_user)

      assert_user_created(jit_user)
      assert_role_assigned(jit_user, "Admin")
    end

    test "When the org has custom role mappings" do
      {:ok, jit_user} =
        Factories.SamlJitUser.insert(
          org_id: @org_id,
          attributes: %{"role" => ["role_1", "test_role"]}
        )

      {:ok, admin} = Repo.RbacRole.get_role_by_name("Admin", "org_scope", jit_user.org_id)
      {:ok, owner} = Repo.RbacRole.get_role_by_name("Owner", "org_scope", jit_user.org_id)

      Factories.IdpGroupMapping.insert(
        organization_id: jit_user.org_id,
        default_role_id: admin.id,
        role_mapping: [%{idp_role_id: "test_role", semaphore_role_id: owner.id}]
      )

      {:ok, jit_user} = AddUser.run(jit_user)

      assert_user_created(jit_user)
      assert_role_assigned(jit_user, "Owner")
    end

    test "When the org has custom group mappings" do
      {:ok, jit_user} =
        Factories.SamlJitUser.insert(
          org_id: @org_id,
          attributes: %{"member" => ["g1", "g2", "unmapped_group"]}
        )

      {:ok, group1} = Factories.Group.insert(organization_id: @org_id)
      {:ok, group2} = Factories.Group.insert(organization_id: @org_id)
      {:ok, member} = Repo.RbacRole.get_role_by_name("Member", "org_scope", jit_user.org_id)

      Factories.IdpGroupMapping.insert(
        organization_id: jit_user.org_id,
        default_role_id: member.id,
        group_mapping: [
          %{idp_group_id: "g1", semaphore_group_id: group1.id},
          %{idp_group_id: "g2", semaphore_group_id: group2.id}
        ]
      )

      {:ok, jit_user} = AddUser.run(jit_user)

      assert_user_created(jit_user)
      assert_role_assigned(jit_user, "Member")
      assert_group_request(jit_user.user_id, group1.id)
      assert_group_request(jit_user.user_id, group2.id)

      assert Repo.GroupManagementRequest |> Repo.aggregate(:count) == 2
    end
  end

  defp assert_user_created(jit_user) do
    import Ecto.Query

    assert Repo.RbacUser |> where([u], u.id == ^jit_user.user_id) |> Repo.exists?()
    assert FrontRepo.User |> where([u], u.id == ^jit_user.user_id) |> FrontRepo.exists?()
  end

  defp assert_role_assigned(jit_user, role_name) do
    import Ecto.Query

    {:ok, role} = Repo.RbacRole.get_role_by_name(role_name, "org_scope", jit_user.org_id)

    Repo.SubjectRoleBinding
    |> where(
      [s],
      s.subject_id == ^jit_user.user_id and s.org_id == ^jit_user.org_id and s.role_id == ^role.id and
        is_nil(s.project_id)
    )
    |> Repo.exists?()
    |> assert()
  end

  defp assert_group_request(user_id, group_id) do
    import Ecto.Query

    Repo.GroupManagementRequest
    |> where([r], r.user_id == ^user_id and r.group_id == ^group_id and r.action == :add_user)
    |> Repo.exists?()
    |> assert()
  end
end
