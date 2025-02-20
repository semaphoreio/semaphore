defmodule Guard.Store.MembersTest do
  use Guard.RepoCase, async: true
  alias Guard.{FrontRepo, Repo}
  alias Guard.Store.Members

  setup do
    Guard.FakeServers.setup_responses_for_development()

    FrontRepo.delete_all(FrontRepo.Member)
    FrontRepo.delete_all(FrontRepo.RepoHostAccount)
    FrontRepo.delete_all(FrontRepo.User)

    Repo.delete_all(Repo.Collaborator)
    Repo.delete_all(Repo.Project)
    Repo.delete_all(Repo.User)

    org_id = Ecto.UUID.generate()
    project_id = Ecto.UUID.generate()

    {:ok, _} = Support.Projects.insert(project_id: project_id, org_id: org_id)

    [
      org_id: org_id,
      project_id: project_id
    ]
  end

  describe "count_memberships" do
    test "returns 0 if there are no memberships", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      assert Members.count_memberships(member, org_id) == 0
    end

    test "returns 1 if there is one membership", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      assert Members.count_memberships(member, org_id) == 1
    end

    test "returns 2 if there is two memberships", %{org_id: org_id} do
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, member2} =
        Support.Members.insert_member(organization_id: org_id, repo_host: "bitbucket")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member2.github_uid,
          user_id: user.id,
          repo_host: member2.repo_host
        )

      assert Members.count_memberships(member, org_id) == 2
      assert Members.count_memberships(member2, org_id) == 2
    end
  end

  describe "extract_user_id" do
    test "returns nil if there are no user", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      assert Members.extract_user_id(member) == nil
    end

    test "returns user_id if there is a user", %{org_id: org_id} do
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      assert Members.extract_user_id(member) == user.id
    end
  end

  describe "project" do
    test "returns empty list if there is no project", %{org_id: org_id} do
      {:ok, []} = Members.project(org_id, Ecto.UUID.generate())
    end

    test "returns empty list if there are no members in the organization", %{
      org_id: org_id,
      project_id: project_id
    } do
      {:ok, []} = Members.project(org_id, project_id)
    end

    test "returns empty list if there are no members in the project", %{
      project_id: project_id,
      org_id: org_id
    } do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, []} = Members.project(org_id, project_id)
    end

    test "returns members for a given project", %{project_id: project_id, org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "John")

      list_members_response =
        InternalApi.RBAC.ListMembersResponse.new(
          members: [
            InternalApi.RBAC.ListMembersResponse.Member.new(
              subject:
                InternalApi.RBAC.Subject.new(
                  subject_id: user.id,
                  subject_type: InternalApi.RBAC.SubjectType.value(:USER),
                  display_name: user.name
                ),
              subject_role_bindings: [
                InternalApi.RBAC.SubjectRoleBinding.new(
                  role: InternalApi.RBAC.Role.new(id: Ecto.UUID.generate()),
                  org_id: org_id
                )
              ]
            )
          ]
        )

      FunRegistry.set!(Support.Fake.RbacService, :list_members, list_members_response)

      {:ok, _rha} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, [m]} = Members.project(org_id, project_id)

      assert m.user_id == user.id
      assert m.display_name == user.name
      assert Enum.count(m.providers) == 1
    end
  end

  describe "organization" do
    test "returns empty list if there are no members", %{org_id: org_id} do
      {:ok, []} = Members.organization(org_id)
    end

    test "returns member for given organization_id", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, [m]} = Members.organization(org_id)

      assert m.user_id == user.id
      assert m.display_name == user.name
      assert Enum.count(m.providers) == 1
    end

    test "returns member with 2 providers when both are members", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      {:ok, member2} =
        Support.Members.insert_member(organization_id: org_id, repo_host: "bitbucket")

      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "johnbb",
          github_uid: member2.github_uid,
          user_id: user.id,
          repo_host: member2.repo_host
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, [m]} = Members.organization(org_id)

      assert m.user_id == user.id
      assert m.display_name == user.name
      assert Enum.count(m.providers) == 2
    end

    test "returns member with 2 providers when only one is a member", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "johnbb",
          user_id: user.id,
          repo_host: "bitbucket"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, [m]} = Members.organization(org_id)

      assert m.user_id == user.id
      assert m.display_name == user.name
      assert Enum.count(m.providers) == 2
    end

    test "returns member filtered by name", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "Klark")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "klarbb",
          user_id: user.id,
          repo_host: "bitbucket"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "klar",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, member2} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user2} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "johnbb",
          user_id: user2.id,
          repo_host: "bitbucket"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member2.github_uid,
          user_id: user2.id,
          repo_host: member2.repo_host
        )

      {:ok, member3} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user3} = Support.Members.insert_user(name: "Zar")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "aklarbb",
          user_id: user3.id,
          repo_host: "bitbucket"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "aklar",
          github_uid: member3.github_uid,
          user_id: user3.id,
          repo_host: member3.repo_host
        )

      {:ok, [m1, m3]} = Members.organization(org_id, name_contains: "Klar")

      assert m1.user_id == user.id
      assert m1.display_name == user.name

      assert Enum.find_value(m1.providers, fn p -> if p.provider == "bitbucket", do: p.login end) ==
               "klarbb"

      assert m3.user_id == user3.id
      assert m3.display_name == user3.name
    end
  end

  describe "cleanup" do
    test "removes all members for a given user", %{org_id: org_id} do
      # First user setup
      {:ok, user1} = Support.Members.insert_user(name: "John")

      # Create two members linked to the first user via repo host accounts
      {:ok, member1} = Support.Members.insert_member(organization_id: org_id)

      {:ok, member2} =
        Support.Members.insert_member(organization_id: org_id, repo_host: "bitbucket")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member1.github_uid,
          user_id: user1.id,
          repo_host: member1.repo_host
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member2.github_uid,
          user_id: user1.id,
          repo_host: member2.repo_host
        )

      # Second user setup
      {:ok, user2} = Support.Members.insert_user(name: "Jane")
      {:ok, member3} = Support.Members.insert_member(organization_id: org_id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "jane",
          github_uid: member3.github_uid,
          user_id: user2.id,
          repo_host: member3.repo_host
        )

      # Cleanup only user1's members
      Members.cleanup(org_id, user1.id, nil)

      # Verify that only user2's member remains
      members = FrontRepo.all(FrontRepo.Member)
      assert length(members) == 1
      [remaining_member] = members
      assert remaining_member.id == member3.id
    end

    test "removes specific member by member_id", %{org_id: org_id} do
      # Create two members
      {:ok, member1} = Support.Members.insert_member(organization_id: org_id)
      {:ok, member2} = Support.Members.insert_member(organization_id: org_id)

      Members.cleanup(org_id, nil, member1.id)

      members = FrontRepo.all(FrontRepo.Member)
      assert length(members) == 1
      assert hd(members).id == member2.id
    end

    test "does nothing when both user_id and member_id are nil", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      Members.cleanup(org_id, nil, nil)

      members = FrontRepo.all(FrontRepo.Member)
      assert length(members) == 1
      assert hd(members).id == member.id
    end

    test "does nothing when user_id is empty string", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      Members.cleanup(org_id, "", nil)

      members = FrontRepo.all(FrontRepo.Member)
      assert length(members) == 1
      assert hd(members).id == member.id
    end

    test "does nothing when member_id is empty string", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      Members.cleanup(org_id, nil, "")

      members = FrontRepo.all(FrontRepo.Member)
      assert length(members) == 1
      assert hd(members).id == member.id
    end
  end
end
