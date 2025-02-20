defmodule Support.Factories.Project do
  alias Projecthub.Models.Project
  alias Projecthub.Repo
  alias Projecthub.Models.Project.StateMachine

  def create(params \\ %{}) do
    changeset =
      %{
        organization_id: Ecto.UUID.generate(),
        name: "my_project",
        slug: "github/my_project",
        creator_id: Ecto.UUID.generate(),
        artifact_store_id: Ecto.UUID.generate(),
        cache_id: nil,
        description: "It's my project",
        created_at: DateTime.utc_now(),
        state: StateMachine.ready(),
        custom_permissions: true,
        debug_empty: true
      }
      |> Map.merge(params)
      |> Project.changeset()

    Repo.insert(changeset)
  end

  def create_with_repo(project_params \\ %{}, repo_params \\ %{}) do
    {:ok, project} = create(project_params)

    {:ok, repository} =
      repo_params
      |> Map.merge(%{project_id: project.id, creator_id: project.creator_id})
      |> Support.Factories.Repository.create()

    {:ok, %{project | repository: repository}}
  end

  def move_in_time(project, datetime) do
    project
    |> Project.changeset(%{created_at: datetime, updated_at: datetime})
    |> Repo.update()
  end
end
