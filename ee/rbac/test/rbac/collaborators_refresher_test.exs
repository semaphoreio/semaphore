defmodule Rbac.CollaboratorsRefresher.Test do
  use Rbac.RepoCase

  import Ecto.Query
  import Mock

  setup do
    Support.Rbac.Store.clear!()

    {:ok, worker} = Rbac.Workers.RefreshProjectAccess.start_link()
    on_exit(fn -> Process.exit(worker, :kill) end)

    :ok
  end

  describe ".refresh" do
    test "sync the collaborators list" do
      alias InternalApi.Repository.Collaborator

      list_collaborators = %InternalApi.Repository.ListCollaboratorsResponse{
        next_page_token: "",
        collaborators: [
          %Collaborator{id: "2", login: "bar", permission: :ADMIN},
          %Collaborator{id: "3", login: "baz", permission: :WRITE},
          %Collaborator{id: "4", login: "bam", permission: :READ}
        ]
      }

      GrpcMock.stub(RepositoryMock, :list_collaborators, fn _, _ ->
        list_collaborators
      end)

      project = Support.Factories.project()

      response = %InternalApi.Projecthub.DescribeResponse{
        metadata: Support.Factories.response_meta(),
        project: project
      }

      GrpcMock.stub(ProjecthubMock, :describe, fn _, _ -> response end)

      {:ok, project} =
        Rbac.Store.Project.update(
          project.metadata.id,
          "renderedtext/semaphore2",
          "15324ba0-1b20-49d0-8ff9-a2d91fa451e0",
          "github",
          "private"
        )

      Rbac.Store.Project.add_collaborator(
        project.project_id,
        %{
          "id" => "1",
          "login" => "foo",
          "permissions" => %{"admin" => true, "push" => true, "pull" => true}
        }
      )

      Rbac.Store.Project.add_collaborator(
        project.project_id,
        %{
          "id" => "2",
          "login" => "bar",
          "permissions" => %{"admin" => true, "push" => true, "pull" => true}
        }
      )

      Rbac.Store.Project.add_collaborator(
        project.project_id,
        %{
          "id" => "3",
          "login" => "baz",
          "permissions" => %{"admin" => false, "push" => false, "pull" => true}
        }
      )

      {:ok, list} = Rbac.Store.Project.collaborators_for_sync(project.project_id)

      assert list == [
               %{
                 "id" => "1",
                 "login" => "foo",
                 "permissions" => %{"admin" => true, "pull" => true, "push" => true}
               },
               %{
                 "id" => "2",
                 "login" => "bar",
                 "permissions" => %{"admin" => true, "pull" => true, "push" => true}
               },
               %{
                 "id" => "3",
                 "login" => "baz",
                 "permissions" => %{"admin" => false, "pull" => true, "push" => false}
               }
             ]

      [user1, user2, user3, user4] =
        rbac_users =
        1..4
        |> Enum.map(fn _ ->
          {:ok, user} = Support.Factories.RbacUser.insert()
          user
        end)

      Enum.each(rbac_users, fn user ->
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )
      end)

      {:ok, _org_scope} = Support.Factories.Scope.insert("org_scope")
      {:ok, project_scope} = Support.Factories.Scope.insert("project_scope")

      {:ok, role1} = Support.Factories.RbacRole.insert(scope_id: project_scope.id)
      {:ok, role2} = Support.Factories.RbacRole.insert(scope_id: project_scope.id)
      {:ok, role3} = Support.Factories.RbacRole.insert(scope_id: project_scope.id)

      {:ok, repo_to_role_mapping} =
        Support.Factories.RepoToRoleMapping.insert(
          org_id: project.org_id,
          admin_role_id: role1.id,
          push_role_id: role2.id,
          pull_role_id: role3.id
        )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user1.id,
        org_id: project.org_id,
        project_id: project.project_id,
        binding_source: :github
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user2.id,
        org_id: project.org_id,
        project_id: project.project_id,
        binding_source: :github
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user3.id,
        org_id: project.org_id,
        project_id: project.project_id,
        binding_source: :github
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user3.id,
        org_id: project.org_id,
        project_id: project.project_id,
        binding_source: :manually_assigned
      )

      # User3 and user4 need to be assigned a project role during collaborators refreshment.
      # For that to be possible, they must have org roles assigned already.
      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user3.id,
        org_id: project.org_id,
        binding_source: :manually_assigned
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user4.id,
        org_id: project.org_id,
        binding_source: :manually_assigned
      )

      with_mocks [
        {Rbac.Store.User, [],
         [
           find_id_by_provider_uid: fn github_uid, _ ->
             case github_uid do
               "1" -> user1.id
               "2" -> user2.id
               "3" -> user3.id
               "4" -> user4.id
             end
           end
         ]}
      ] do
        :ok = Rbac.CollaboratorsRefresher.refresh(project)
        # Giving time for message broker to
        :timer.sleep(500)
        Rbac.Workers.RefreshProjectAccess.perform_now()
        # Giving time for rbac refresh workers to process all the messages
        :timer.sleep(1000)

        {:ok, list} = Rbac.Store.Project.collaborators_for_sync(project.project_id)

        assert list == [
                 %{
                   "id" => "2",
                   "login" => "bar",
                   "permissions" => %{"admin" => true, "pull" => true, "push" => true}
                 },
                 %{
                   "id" => "3",
                   "login" => "baz",
                   "permissions" => %{"admin" => false, "pull" => true, "push" => true}
                 },
                 %{
                   "id" => "4",
                   "login" => "bam",
                   "permissions" => %{"admin" => false, "pull" => true, "push" => false}
                 }
               ]

        # 4 project level roles and 2 org level roles
        assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length() == 6

        assert Rbac.Repo.SubjectRoleBinding
               |> where(
                 [srb],
                 srb.subject_id == ^user4.id and
                   srb.role_id == ^repo_to_role_mapping.pull_access_role_id
               )
               |> Rbac.Repo.one() != nil

        assert Rbac.Repo.SubjectRoleBinding
               |> where(
                 [srb],
                 srb.subject_id == ^user1.id
               )
               |> Rbac.Repo.one() == nil
      end
    end

    test "does not create refresh requests when org has no RepoToRoleMapping" do
      alias InternalApi.Repository.Collaborator

      list_collaborators = %InternalApi.Repository.ListCollaboratorsResponse{
        next_page_token: "",
        collaborators: [
          %Collaborator{id: "3", login: "baz", permission: :WRITE},
          %Collaborator{id: "4", login: "bam", permission: :READ}
        ]
      }

      GrpcMock.stub(RepositoryMock, :list_collaborators, fn _, _ ->
        list_collaborators
      end)

      project = Support.Factories.project()

      response = %InternalApi.Projecthub.DescribeResponse{
        metadata: Support.Factories.response_meta(),
        project: project
      }

      GrpcMock.stub(ProjecthubMock, :describe, fn _, _ -> response end)

      {:ok, project} =
        Rbac.Store.Project.update(
          project.metadata.id,
          "renderedtext/semaphore2",
          "15324ba0-1b20-49d0-8ff9-a2d91fa451e0",
          "github",
          "private"
        )

      [user1, user2, user3, user4] =
        rbac_users =
        1..4
        |> Enum.map(fn _ ->
          {:ok, user} = Support.Factories.RbacUser.insert()
          user
        end)

      Enum.each(rbac_users, fn user ->
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )
      end)

      {:ok, _org_scope} = Support.Factories.Scope.insert("org_scope")

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user3.id,
        org_id: project.org_id,
        binding_source: :manually_assigned
      )

      Support.Factories.SubjectRoleBinding.insert(
        subject_id: user4.id,
        org_id: project.org_id,
        binding_source: :manually_assigned
      )

      with_mocks [
        {Rbac.Store.User, [],
         [
           find_id_by_provider_uid: fn github_uid, _ ->
             case github_uid do
               "1" -> user1.id
               "2" -> user2.id
               "3" -> user3.id
               "4" -> user4.id
             end
           end
         ]}
      ] do
        assert :ok = Rbac.CollaboratorsRefresher.refresh(project)

        # Giving time for message broker to process
        :timer.sleep(500)
        Rbac.Workers.RefreshProjectAccess.perform_now()
        :timer.sleep(1000)

        refresh_requests = Rbac.Repo.RbacRefreshProjectAccessRequest |> Rbac.Repo.all()
        assert refresh_requests == []
      end
    end
  end
end
