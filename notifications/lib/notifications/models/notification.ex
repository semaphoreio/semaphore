defmodule Notifications.Models.Notification do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger
  alias Notifications.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    has_many(:rules, Notifications.Models.Rule, on_delete: :delete_all)

    field(:org_id, :binary_id)
    field(:creator_id, :binary_id)
    field(:name, :string)
    field(:spec, :map)

    timestamps()
  end

  def new(org_id, name, creator_id, spec) do
    %__MODULE__{}
    |> changeset(%{
      org_id: org_id,
      creator_id: creator_id,
      name: name,
      spec: spec
    })
  end

  #
  # Lookup
  #

  def find(org_id, id) do
    case Repo.get_by(__MODULE__, org_id: org_id, id: id) do
      nil -> {:error, :not_found}
      notification -> {:ok, notification}
    end
  end

  def find_by_name(org_id, name) do
    case Repo.get_by(__MODULE__, org_id: org_id, name: name) do
      nil -> {:error, :not_found}
      notification -> {:ok, notification}
    end
  end

  def find_by_id_or_name(org_id, id_or_name) do
    if uuid?(id_or_name) do
      find(org_id, id_or_name)
    else
      find_by_name(org_id, id_or_name)
    end
  end

  def uuid?(id_or_name) do
    case Ecto.UUID.dump(id_or_name) do
      {:ok, _} -> true
      _ -> false
    end
  end

  #
  # Scopes
  #

  def order_by_name_asc(query) do
    query |> order_by([s], s.name)
  end

  def order_by_create_time_asc(query) do
    query |> order_by([s], s.inserted_at)
  end

  def in_org(query, org_id) do
    query |> where([s], s.org_id == ^org_id)
  end

  def changeset(notification, params \\ %{}) do
    notification
    |> cast(params, [:org_id, :creator_id, :name, :spec])
    |> validate_required([:org_id, :creator_id, :name, :spec])
    |> valid_name_format(params)
    |> unique_constraint(
      :unique_names,
      name: :unique_names_in_organization,
      message: "name '#{params.name}' has already been taken"
    )
  end

  defp valid_name_format(changeset, params) do
    if uuid?(params.name) do
      changeset |> add_error(:name_format, "name should not be in uuid format")
    else
      changeset
    end
  end
end
