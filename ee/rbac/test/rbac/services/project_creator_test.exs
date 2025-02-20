defmodule Rbac.Services.ProjectCreatedTest do
  use Rbac.RepoCase

  import Mock

  setup do
    Support.Rbac.Store.clear!()
    :ok
  end

  describe ".handle_message" do
    test "message processing when the server is available" do
      alias InternalApi.Repository.Collaborator

      {:ok, _org_scope} = Support.Factories.Scope.insert("org_scope")

      list_collaborators =
        %InternalApi.Repository.ListCollaboratorsResponse{
          next_page_token: "",
          collaborators: [
            %Collaborator{id: "2", login: "bar", permission: :ADMIN},
            %Collaborator{id: "3", login: "baz", permission: :WRITE},
            %Collaborator{id: "4", login: "bam", permission: :READ}
          ]
        }

      GrpcMock.stub(RepositoryMock, :list_collaborators, list_collaborators)

      project = Support.Factories.project()

      response =
        %InternalApi.Projecthub.DescribeResponse{
          metadata: Support.Factories.response_meta(),
          project: project
        }

      GrpcMock.stub(ProjecthubMock, :describe, response)

      user = Support.Factories.user()

      {:ok, front_user} =
        %Rbac.FrontRepo.User{
          id: user.user_id,
          name: user.name,
          email: user.email
        }
        |> Rbac.FrontRepo.insert()

      {:ok, _repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          repo_host: "github",
          refresh_token: "example_refresh_token",
          user_id: front_user.id,
          permission_scope: "repo",
          github_uid: "184065"
        )

      Rbac.Store.User.update("8cbf8429-4230-4973-8d65-1e98b7d2ca65", "github", "2", "private")
      Rbac.Store.User.update("8cbf8429-4230-4973-8d65-1e98b7d2ca66", "github", "3", "private")
      Rbac.Store.User.update("8cbf8429-4230-4973-8d65-1e98b7d2ca67", "github", "4", "private")
      Rbac.Store.User.update("8cbf8429-4230-4973-8d65-1e98b7d2ca69", "github", "5", "private")

      with_mocks([
        {
          Rbac.Repo.RepoToRoleMapping,
          [],
          [get_project_role_from_repo_access_rights: fn _, _, _, _ -> :ok end]
        },
        {
          Rbac.Repo.RbacRefreshProjectAccessRequest,
          [],
          [add_request: fn _, _, _, _, _, _ -> :ok end]
        }
      ]) do
        publish_event(project)

        :timer.sleep(300)
      end

      assert {:ok,
              %Rbac.Repo.Project{
                org_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca64",
                project_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
                repo_name: "renderedtext/rbac",
                repository_id: "1e2e6241-f30b-4892-a0d5-bd900b713430"
              }} = Rbac.Store.Project.find(project.metadata.id)

      assert [
               %{
                 github_uid: "2",
                 project_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
                 user_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca65"
               },
               %{
                 github_uid: "3",
                 project_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
                 user_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca66"
               },
               %{
                 github_uid: "4",
                 project_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
                 user_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca67"
               }
             ] = Rbac.Store.Project.members(project.metadata.id)
    end
  end

  #
  # Helpers
  #

  def publish_event(project) do
    event = %InternalApi.Projecthub.ProjectCreated{project_id: project.metadata.id}

    message = InternalApi.Projecthub.ProjectCreated.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "project_exchange",
      routing_key: "created"
    }

    Tackle.publish(message, options)
  end
end
