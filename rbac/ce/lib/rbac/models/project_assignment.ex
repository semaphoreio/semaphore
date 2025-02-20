defmodule Rbac.Models.ProjectAssignment do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Rbac.Repo

  @primary_key false
  @foreign_key_type :binary_id
  schema "project_assignment" do
    field(:org_id, :binary_id, primary_key: true)
    field(:project_id, :binary_id, primary_key: true)
    field(:user_id, :binary_id, primary_key: true)

    timestamps(inserted_at: :created_at, updated_at: :updated_at)
  end

  @doc false
  def changeset(project_assignment, attrs) do
    project_assignment
    |> cast(attrs, [:org_id, :project_id, :user_id])
    |> validate_required([:org_id, :project_id, :user_id])
  end

  @doc """
  Gets a single project_assignment by user_id and project_id.
  """
  def get_by_user_and_project_id(user_id, project_id) do
    Repo.get_by(__MODULE__, user_id: user_id, project_id: project_id)
  end

  @doc """
  Gets all project_assignments for a user in an org.
  """
  def get_by_user_and_org_id(user_id, org_id) do
    Repo.all(from(p in __MODULE__, where: p.user_id == ^user_id and p.org_id == ^org_id))
  end

  @doc """
  Get all user_ids for a project in an org.
  """
  def get_user_ids_by_org_project(org_id, project_id) do
    Repo.all(from(p in __MODULE__, where: p.org_id == ^org_id and p.project_id == ^project_id))
    |> Enum.map(& &1.user_id)
  end

  @doc """
  Gets all project_ids for a user in an org.
  """
  def get_project_ids_by_user_id_and_org_id(user_id, org_id) do
    from(p in __MODULE__, where: p.user_id == ^user_id and p.org_id == ^org_id)
    |> select([p], p.project_id)
    |> Repo.all()
  end

  @doc """
  Creates a project_assignment.

  ## Examples

      iex> create(%{field: value})
      {:ok, %ProjectAssignment{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a project_assignment.

  ## Examples

      iex> delete(project_assignment)
      {:ok, %ProjectAssignment{}}

      iex> delete(project_assignment)
      {:error, %Ecto.Changeset{}}

  """
  def delete(%__MODULE__{} = project_assignment) do
    Repo.delete(project_assignment)
  end

  @doc """
  Deletes all project_assignments for a project.
  """
  def delete_all_for_project(project_id) do
    Repo.delete_all(from(p in __MODULE__, where: p.project_id == ^project_id))
  end

  @doc """
  Deletes all project_assignments for a user in an org.
  """
  def delete_all_for_user_in_org(user_id, org_id) do
    Repo.delete_all(from(p in __MODULE__, where: p.user_id == ^user_id and p.org_id == ^org_id))
  end
end
