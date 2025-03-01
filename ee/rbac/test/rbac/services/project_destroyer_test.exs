defmodule Rbac.Services.ProjectDestroyerTest do
  use Rbac.RepoCase
  import Ecto.Query

  setup do
    Support.Rbac.Store.clear!()

    project1_id = Ecto.UUID.generate()
    project2_id = Ecto.UUID.generate()
    org_id = Ecto.UUID.generate()

    {:ok, project_scope} = Support.Factories.Scope.insert("project_scope")
    {:ok, _} = Support.Factories.Scope.insert("org_scope")

    {:ok, project_role} =
      Support.Factories.RbacRole.insert(
        scope_id: project_scope.id,
        org_id: org_id
      )

    # Assign roles for project1 and project2
    Support.Factories.SubjectRoleBinding.insert(
      org_id: org_id,
      role_id: project_role.id,
      project_id: project1_id
    )

    Support.Factories.SubjectRoleBinding.insert(
      org_id: org_id,
      role_id: project_role.id,
      project_id: project1_id
    )

    Support.Factories.SubjectRoleBinding.insert(
      org_id: org_id,
      role_id: project_role.id,
      project_id: project2_id
    )

    {:ok,
     %{
       project1_id: project1_id,
       project2_id: project2_id,
       org_id: org_id
     }}
  end

  describe ".handle_message" do
    test "message processing when the server is avaible", state do
      project = Support.Factories.project(org_id: state.org_id, id: state.project1_id)

      Rbac.Store.Project.update(
        project.metadata.id,
        "foo/bar",
        "15324ba0-1b20-49d0-8ff9-a2d91fa451e0",
        "github",
        project.spec.repository.id
      )

      {:ok, _} = Rbac.Store.Project.find(project.metadata.id)

      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length() == 3
      publish_event(project)

      :timer.sleep(100)

      assert Rbac.Store.Project.find(project.metadata.id) == {:error, :project_not_found}

      assert Rbac.Repo.SubjectRoleBinding
             |> where([srb], srb.project_id == ^state.project1_id)
             |> Rbac.Repo.all()
             |> length() == 0

      assert Rbac.Repo.SubjectRoleBinding
             |> where([srb], srb.project_id == ^state.project2_id)
             |> Rbac.Repo.all()
             |> length() == 1
    end
  end

  #
  # Helpers
  #

  def publish_event(project) do
    event = %InternalApi.Projecthub.ProjectDeleted{
      org_id: project.metadata.org_id,
      project_id: project.metadata.id
    }

    message = InternalApi.Projecthub.ProjectDeleted.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "project_exchange",
      routing_key: "deleted"
    }

    Tackle.publish(message, options)
  end
end
