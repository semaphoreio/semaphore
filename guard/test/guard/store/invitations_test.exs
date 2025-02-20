defmodule Guard.Store.InvitationsTest do
  use Guard.RepoCase, async: true
  alias Guard.FrontRepo
  alias Guard.FrontRepo.{Member, RepoHostAccount, User}

  alias Guard.Repo
  alias Guard.Repo.{Collaborator, Project}

  alias Guard.Store.Invitations

  setup do
    Guard.FakeServers.setup_responses_for_development()

    FrontRepo.delete_all(User)
    FrontRepo.delete_all(Member)
    FrontRepo.delete_all(RepoHostAccount)

    Repo.delete_all(Collaborator)
    Repo.delete_all(Project)

    org_id = Ecto.UUID.generate()

    [
      org_id: org_id
    ]
  end

  describe "create" do
    test "do not create when invalid params", %{org_id: org_id} do
      invitees = [
        %{email: "", name: "", provider: %{login: "", uid: "", type: :GITHUB}}
      ]

      {:ok, []} = Invitations.create(invitees, org_id)
    end

    test "insert member with valid params", %{org_id: org_id} do
      invitees = [
        %{email: "", name: "", provider: %{login: "radwo", uid: "184065", type: :GITHUB}}
      ]

      {:ok, [member]} = Invitations.create(invitees, org_id)

      assert member.github_username == "radwo"
      assert member.github_uid == "184065"
      assert member.repo_host == "github"
      assert member.organization_id == org_id
      assert member.invite_email == nil
    end

    test "do not insert duplicate member", %{org_id: org_id} do
      invitees = [
        %{email: "", name: "", provider: %{login: "radwo", uid: "184065", type: :GITHUB}},
        %{email: "", name: "", provider: %{login: "radwo", uid: "184065", type: :GITHUB}}
      ]

      {:ok, members} = Invitations.create(invitees, org_id)

      assert Enum.count(members) == 1
    end

    test "updates user for duplicate member", %{org_id: org_id} do
      invitee = %{email: "", name: "", provider: %{login: "radwo", uid: "184065", type: :GITHUB}}
      Invitations.create([invitee], org_id)

      invitee = %{
        email: "rwozniak@renderedtext.com",
        name: "Radosław Woźniak",
        provider: %{login: "radwo", uid: "184065", type: :GITHUB}
      }

      assert {:ok, [member]} = Invitations.create([invitee], org_id)
      assert member.invite_email == invitee.email
      assert member.github_uid == invitee.provider.uid
    end
  end

  describe "list" do
    test "returns empty list if there are no invitations", %{org_id: org_id} do
      {:ok, []} = Invitations.list(org_id)
    end

    test "returns invitations for given organization_id", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)

      {:ok, [invitation]} = Invitations.list(org_id)

      assert invitation.id == member.id
      assert invitation.display_name == member.github_username
    end

    test "do not returns already joined members for given organization_id", %{org_id: org_id} do
      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, member2} = Support.Members.insert_member(organization_id: org_id)

      {:ok, [invitation]} = Invitations.list(org_id)

      assert invitation.id == member2.id
      assert invitation.display_name == member2.github_username
    end

    test "returns all invitations for given organization_id", %{org_id: org_id} do
      {:ok, _} = Support.Members.insert_member(organization_id: org_id)
      {:ok, _} = Support.Members.insert_member(organization_id: org_id)

      {:ok, invitations} = Invitations.list(org_id)

      assert Enum.count(invitations) == 2
    end
  end

  describe "collaborators" do
    test "returns empty list if there are no collaborators", %{org_id: org_id} do
      {:ok, []} = Invitations.collaborators(org_id)
    end

    test "returns collaborators for given organization_id", %{org_id: org_id} do
      {:ok, project} = Support.Projects.insert(org_id: org_id)
      {:ok, collaborator} = Support.Collaborators.insert(project_id: project.project_id)

      {:ok, [col]} = Invitations.collaborators(org_id)

      assert col.login == collaborator.github_username
    end

    test "do not return collaborator if already a member or invited", %{org_id: org_id} do
      {:ok, project} = Support.Projects.insert(org_id: org_id)

      {:ok, collaborator} =
        Support.Collaborators.insert(project_id: project.project_id, github_username: "paul")

      {:ok, collaborator2} =
        Support.Collaborators.insert(project_id: project.project_id, github_username: "greg")

      {:ok, _} =
        Support.Members.insert_member(
          github_username: collaborator.github_username,
          github_uid: collaborator.github_uid
        )

      {:ok, _} =
        Support.Members.insert_member(
          organization_id: org_id,
          github_username: collaborator2.github_username,
          github_uid: collaborator2.github_uid
        )

      {:ok, member} = Support.Members.insert_member(organization_id: org_id)
      {:ok, user} = Support.Members.insert_user(name: "John")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      {:ok, rha2} = Support.Members.insert_repo_host_account(user_id: user.id)

      {:ok, _collaborator} =
        Support.Collaborators.insert(
          project_id: project.project_id,
          github_username: "john",
          github_uid: member.github_uid
        )

      {:ok, _collaborator} =
        Support.Collaborators.insert(
          project_id: project.project_id,
          github_username: rha2.login,
          github_uid: rha2.github_uid
        )

      {:ok, [col]} = Invitations.collaborators(org_id)

      assert col.login == collaborator.github_username
    end

    test "returns only collaborators for given project_id", %{org_id: org_id} do
      {:ok, project} = Support.Projects.insert(org_id: org_id)

      {:ok, collaborator} = Support.Collaborators.insert(project_id: project.project_id)

      {:ok, _} =
        Support.Members.insert_member(
          github_username: collaborator.github_username,
          github_uid: collaborator.github_uid
        )

      {:ok, project2} = Support.Projects.insert(org_id: org_id)
      {:ok, collaborator2} = Support.Collaborators.insert(project_id: project2.project_id)

      {:ok, _} =
        Support.Members.insert_member(
          github_username: collaborator2.github_username,
          github_uid: collaborator2.github_uid
        )

      {:ok, [col]} = Invitations.collaborators(org_id, project.project_id)

      assert col.login == collaborator.github_username
    end
  end
end
