defmodule Rbac.Repo.CollaboratorRefreshRequest do
  use Rbac.Repo.Schema

  require Ecto.Query
  import Ecto.Query

  @timestamps_opts [type: :utc_datetime]

  @required_fields [
    :org_id,
    :remaining_project_ids,
    :state
  ]

  @updatable_fields [
    :state,
    :remaining_project_ids,
    :inserted_at,
    :updated_at,
    :requester_user_id
  ]

  schema "collaborator_refresh_requests" do
    field(:org_id, :binary_id)
    field(:remaining_project_ids, {:array, :binary_id})
    field(:state, Ecto.Enum, values: [:pending, :done])
    field(:requester_user_id, :binary_id)

    timestamps()
  end

  def new(org_id, project_ids, user_id) do
    %__MODULE__{
      org_id: org_id,
      remaining_project_ids: project_ids,
      state: :pending,
      requester_user_id: user_id
    }
  end

  def load(id) do
    Rbac.Repo.get(__MODULE__, id)
  end

  def load_with_lock(id, options \\ [], fun) do
    Rbac.Repo.transaction(
      fn ->
        from(r in __MODULE__, where: r.id == ^id, lock: "FOR UPDATE SKIP LOCKED")
        |> Rbac.Repo.one()
        |> case do
          nil -> nil
          result -> fun.(result)
        end
      end,
      options
    )
  end

  def load_pending do
    from(r in __MODULE__, where: r.state == :pending, select: r.id) |> Rbac.Repo.all()
  end

  def changeset(record, params \\ %{}) do
    record
    |> cast(params, @updatable_fields)
    |> validate_required(@required_fields)
  end
end
