defmodule Rbac.Models.RoleAssignment do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Rbac.Repo

  @primary_key false
  @foreign_key_type :binary_id
  schema "role_assignment" do
    field(:role_id, :binary_id)
    field(:org_id, :binary_id, primary_key: true)
    field(:user_id, :binary_id, primary_key: true)
    field(:subject_type, :string, default: "user")

    timestamps(inserted_at: :created_at, updated_at: :updated_at)
  end

  @doc false
  def changeset(role_assignment, attrs) do
    role_assignment
    |> cast(attrs, [:user_id, :org_id, :role_id, :subject_type])
    |> validate_required([:user_id, :org_id, :role_id])
  end

  @doc """
  Gets a single role_assignment by user_id and org_id.
  """
  def get_by_user_and_org_id(user_id, org_id) do
    Repo.get_by(__MODULE__, user_id: user_id, org_id: org_id)
  end

  @doc """
  Serches for role_assignments based on the given params.s
  """
  def search(params \\ []) do
    query = from(r in __MODULE__, where: true)
    page_number = Keyword.get(params, :page_number, 1)
    page_size = Keyword.get(params, :page_size, 50)

    query =
      Enum.reduce(params, query, fn {key, value}, query ->
        case key do
          :user_ids -> from(r in query, where: r.user_id in ^value)
          :user_id -> from(r in query, where: r.user_id == ^value)
          :org_id -> from(r in query, where: r.org_id == ^value)
          :role_id -> from(r in query, where: r.role_id == ^value)
          :subject_type -> from(r in query, where: r.subject_type == ^value)
          _ -> query
        end
      end)

    total_count_task = Task.async(fn -> Repo.aggregate(query, :count) end)

    results_task =
      Task.async(fn ->
        query
        |> limit(^page_size)
        |> offset(^page_size * (^page_number - 1))
        |> Repo.all()
      end)

    %{results: Task.await(results_task), total_count: Task.await(total_count_task)}
  end

  @doc """
  Gets all role_assignments for a user.
  """
  def get_org_ids_by_user_id(user_id) do
    from(p in __MODULE__, where: p.user_id == ^user_id)
    |> select([p], p.org_id)
    |> Repo.all()
  end

  @doc """
  Get user ids that are owner or admin in the given organization
  """
  def get_owner_and_admin_user_ids(org_id) do
    owner_and_admin_role_ids = [Rbac.Roles.Owner.role().id, Rbac.Roles.Admin.role().id]

    from(p in __MODULE__, where: p.org_id == ^org_id and p.role_id in ^owner_and_admin_role_ids)
    |> select([p], p.user_id)
    |> Repo.all()
  end

  @doc """
  Counts all role_assignments for a given org_id.
  """
  def count_by_org_id(org_id) do
    from(p in __MODULE__, where: p.org_id == ^org_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a role_assignment.

  ## Examples

      iex> create(%{field: value})
      {:ok, %RoleAssignment{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role_assignment.

  ## Examples

      iex> update(role_assignment, %{field: new_value})
      {:ok, %RoleAssignment{}}

      iex> update(role_assignment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update(%__MODULE__{} = role_assignment, attrs) do
    update_changeset =
      role_assignment
      |> changeset(attrs)

    case update_changeset do
      %Ecto.Changeset{valid?: true} ->
        owner_and_admin_role_ids = [Rbac.Roles.Owner.role().id, Rbac.Roles.Admin.role().id]

        if attrs[:role_id] in owner_and_admin_role_ids do
          Rbac.Models.ProjectAssignment.delete_all_for_user_in_org(
            role_assignment.user_id,
            role_assignment.org_id
          )
        end

        Repo.update(update_changeset)

      _ ->
        {:error, update_changeset}
    end
  end

  @doc """
  Assigns owner role to the default user.
  """
  def assign_owner_role(user_id, org_id) do
    role = Rbac.Roles.Owner.role()

    create_or_update(%{
      org_id: org_id,
      user_id: user_id,
      role_id: role.id
    })
  end

  @doc """
  Creates or updates a role_assignment.
  """
  def create_or_update(attrs \\ %{}) do
    assignment = get_by_user_and_org_id(attrs[:user_id], attrs[:org_id])

    if assignment do
      __MODULE__.update(assignment, attrs)
    else
      create(attrs)
    end
  end

  @doc """
  Deletes all role_assignments for a given org_id.
  """
  def delete_from_org(org_id) do
    from(p in __MODULE__, where: p.org_id == ^org_id)
    |> Repo.delete_all()
  end

  @doc """
  Deletes a role_assignment.

  ## Examples

      iex> delete(role_assignment)
      {:ok, %RoleAssignment{}}

      iex> delete(role_assignment)
      {:error, %Ecto.Changeset{}}

  """
  def delete(%__MODULE__{} = role_assignment) do
    if role_assignment.role_id == Rbac.Roles.Member.role().id do
      Rbac.Models.ProjectAssignment.delete_all_for_user_in_org(
        role_assignment.user_id,
        role_assignment.org_id
      )
    end

    Repo.delete(role_assignment)
  end

  @doc """
  Deletes all role_assignments for a given org_id and user_id.
  """
  def delete_by_org_and_user_id(org_id, user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_project_assignments,
      from(p in Rbac.Models.ProjectAssignment,
        where: p.user_id == ^user_id and p.org_id == ^org_id
      )
    )
    |> Ecto.Multi.delete_all(
      :delete_role_assignments,
      from(r in __MODULE__, where: r.user_id == ^user_id and r.org_id == ^org_id)
    )
    |> Repo.transaction()
  end

  @doc """
  Deletes all role_assignments for a given user_id.
  """
  def delete_all_by_user_id(user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_project_assignments,
      from(p in Rbac.Models.ProjectAssignment, where: p.user_id == ^user_id)
    )
    |> Ecto.Multi.delete_all(
      :delete_role_assignments,
      from(r in __MODULE__, where: r.user_id == ^user_id)
    )
    |> Repo.transaction()
  end

  @doc """
  Deletes all role_assignments for a given org_id.
  """
  def delete_all_by_org_id(org_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_project_assignments,
      from(p in Rbac.Models.ProjectAssignment, where: p.org_id == ^org_id)
    )
    |> Ecto.Multi.delete_all(
      :delete_role_assignments,
      from(r in __MODULE__, where: r.org_id == ^org_id)
    )
    |> Repo.transaction()
  end
end
