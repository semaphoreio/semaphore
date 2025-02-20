defmodule Rbac.Store.Project do
  require Logger

  alias Rbac.Repo
  import Ecto.Query

  def touch_update_at(project_id) do
    Repo.Project
    |> where([p], p.project_id == ^project_id)
    |> Repo.update_all(set: [updated_at: "#{DateTime.utc_now()}"])
  end

  def list_projects(org_id) do
    entries = Repo.all(from(p in Repo.Project, where: p.org_id == ^org_id))

    {:ok, entries |> Enum.map(& &1.project_id)}
  end

  def list_projects do
    entries = Repo.all(from(c in Repo.Collaborator, distinct: c.project_id))

    {:ok, entries |> Enum.map(& &1.project_id)}
  end

  def list_collaborators(project_ids) do
    Watchman.benchmark("list_projects_collaborators.duration", fn ->
      Repo.Collaborator
      |> group_by([c], c.github_uid)
      |> select([c], %{
        github_uid: type(c.github_uid, :string),
        github_username: max(c.github_username),
        github_email: max(c.github_email),
        project_ids: fragment("array_agg(project_id::text)")
      })
      |> where([c], c.project_id in ^project_ids)
      |> Repo.all()
    end)
  end

  def collaborators_for_sync(project_id) do
    Watchman.benchmark("list_collaborators.duration", fn ->
      collaborators =
        Repo.Collaborator
        |> select([c], %{
          "id" => c.github_uid,
          "login" => c.github_username,
          "permissions" => %{"admin" => c.admin, "push" => c.push, "pull" => c.pull}
        })
        |> where([c], c.project_id == ^project_id)
        |> Repo.all()

      {:ok, collaborators}
    end)
  end

  def update(project_id, repo_name, org_id, provider, repository_id) do
    changes = %{
      project_id: project_id,
      repo_name: repo_name,
      org_id: org_id,
      provider: provider,
      repository_id: repository_id
    }

    result =
      case Repo.get_by(Repo.Project, project_id: project_id) do
        nil ->
          %Repo.Project{
            project_id: project_id,
            repo_name: repo_name,
            org_id: org_id,
            provider: provider,
            repository_id: repository_id
          }

        user ->
          user
      end
      |> Repo.Project.changeset(changes)
      |> Repo.insert_or_update()

    case result do
      {:ok, p} -> {:ok, p}
      e -> e
    end
  end

  def delete(project_id) do
    case Repo.get_by(Repo.Project, project_id: project_id) do
      nil ->
        {:error, :not_found}

      p ->
        case Repo.delete(p) do
          {:ok, _} -> :ok
          e -> e
        end
    end
  end

  def find(project_id) do
    case Repo.Project |> where(project_id: ^project_id) |> Repo.one() do
      nil -> {:error, :project_not_found}
      p -> {:ok, p}
    end
  end

  def remove_collaborator(project_id, github_uid) do
    case find_collaborator(project_id, github_uid) do
      nil ->
        {:error, :not_found}

      c ->
        case Repo.delete(c) do
          {:ok, _} -> :ok
          e -> e
        end
    end
  rescue
    _ in Ecto.StaleEntryError -> :ok
  end

  def add_collaborator(project_id, collaborator) do
    changeset =
      Repo.Collaborator.changeset(%Repo.Collaborator{}, %{
        project_id: project_id,
        github_username: collaborator["login"],
        github_uid: collaborator["id"],
        admin: collaborator["permissions"]["admin"],
        push: collaborator["permissions"]["push"],
        pull: collaborator["permissions"]["pull"]
      })

    case Repo.insert(changeset) do
      {:ok, c} ->
        {:ok, c}

      e ->
        e
    end
  end

  def find_collaborator(project_id, github_uid) do
    Repo.Collaborator |> where(project_id: ^project_id, github_uid: ^github_uid) |> Repo.one()
  end

  def find_collaborator(github_uid) do
    Repo.Collaborator |> where(github_uid: ^github_uid) |> Repo.one()
  end

  def collaborators_email(github_uid) do
    case Repo.Collaborator
         |> where([c], not is_nil(c.github_email) and c.github_uid == ^github_uid)
         |> select([:github_email])
         |> first()
         |> Repo.one() do
      nil -> nil
      collaborator -> collaborator.github_email
    end
  end

  def update_collabortos_email(github_uid, email) do
    Repo.Collaborator
    |> where([c], is_nil(c.github_email) and c.github_uid == ^github_uid)
    |> Repo.update_all(set: [github_email: email])
  end

  def collaborators_count(github_uid) do
    Repo.Collaborator |> where([c], c.github_uid == ^github_uid) |> Repo.aggregate(:count, :id)
  end

  def filter_memberships(project_ids, user_id, permission \\ :pull)

  def filter_memberships(project_ids, user_id, :pull) do
    Repo.all(
      from(p in Repo.Project,
        left_join: c in Repo.Collaborator,
        on: c.project_id == p.project_id,
        left_join: u in Repo.User,
        on: u.github_uid == c.github_uid,
        select: p.project_id,
        where:
          u.user_id == ^user_id and c.project_id in ^project_ids and c.pull == true and
            u.provider == p.provider
      )
    )
  end

  def filter_memberships(project_ids, user_id, :push) do
    Repo.all(
      from(p in Repo.Project,
        left_join: c in Repo.Collaborator,
        on: c.project_id == p.project_id,
        left_join: u in Repo.User,
        on: u.github_uid == c.github_uid,
        select: p.project_id,
        where:
          u.user_id == ^user_id and c.project_id in ^project_ids and c.push == true and
            u.provider == p.provider
      )
    )
  end

  def filter_memberships(project_ids, user_id, :admin) do
    Repo.all(
      from(p in Repo.Project,
        left_join: c in Repo.Collaborator,
        on: c.project_id == p.project_id,
        left_join: u in Repo.User,
        on: u.github_uid == c.github_uid,
        select: p.project_id,
        where:
          u.user_id == ^user_id and c.project_id in ^project_ids and c.admin == true and
            u.provider == p.provider
      )
    )
  end

  def member?(project_id, user_id, permission \\ :pull)

  def member?(project_id, user_id, :pull) do
    case Repo.one(
           from(c in Repo.Collaborator,
             left_join: u in Repo.User,
             on: u.github_uid == c.github_uid,
             left_join: p in Repo.Project,
             on: c.project_id == p.project_id,
             where:
               u.user_id == ^user_id and c.project_id == ^project_id and c.pull == true and
                 u.provider == p.provider
           )
         ) do
      nil ->
        false

      _ ->
        true
    end
  end

  def member?(project_id, user_id, :push) do
    case Repo.one(
           from(c in Repo.Collaborator,
             left_join: u in Repo.User,
             on: u.github_uid == c.github_uid,
             left_join: p in Repo.Project,
             on: c.project_id == p.project_id,
             where:
               u.user_id == ^user_id and c.project_id == ^project_id and c.push == true and
                 u.provider == p.provider
           )
         ) do
      nil ->
        false

      _ ->
        true
    end
  end

  def member?(project_id, user_id, :admin) do
    case Repo.one(
           from(c in Repo.Collaborator,
             left_join: u in Repo.User,
             on: u.github_uid == c.github_uid,
             left_join: p in Repo.Project,
             on: c.project_id == p.project_id,
             where:
               u.user_id == ^user_id and c.project_id == ^project_id and c.admin == true and
                 u.provider == p.provider
           )
         ) do
      nil ->
        false

      _ ->
        true
    end
  end

  def members(project_id) do
    Repo.all(
      from(c in Repo.Collaborator,
        left_join: u in Repo.User,
        on: c.github_uid == u.github_uid,
        left_join: p in Repo.Project,
        on: c.project_id == p.project_id,
        select: %{user_id: u.user_id, project_id: c.project_id, github_uid: u.github_uid},
        where: c.project_id == ^project_id and u.provider == p.provider
      )
    )
  end

  @doc """
    Returns list of project ids to which a given user has access
  """
  def membership(user_id, org_id) do
    {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id)
    org_permissions = Rbac.Store.UserPermissions.read_user_permissions(rbi)
    {:ok, projects} = __MODULE__.list_projects(org_id)

    if org_permissions =~ "project.view" do
      projects
    else
      Rbac.Store.ProjectAccess.get_list_of_projects(user_id, org_id)
      |> Enum.filter(&(&1 in projects))
    end
  end
end
