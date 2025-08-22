defmodule Guard.FrontRepo.Favorite do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Guard.FrontRepo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "favorites" do
    field(:user_id, :binary_id)
    field(:favorite_id, :binary_id)
    field(:kind, :string)
    field(:organization_id, :binary_id)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          favorite_id: String.t(),
          kind: String.t(),
          organization_id: String.t()
        }

  def changeset(favorite, attrs) do
    favorite
    |> cast(attrs, [:user_id, :favorite_id, :kind, :organization_id])
    |> validate_required([:user_id, :favorite_id, :kind, :organization_id])
    |> unique_constraint([:user_id, :organization_id, :favorite_id, :kind],
      name: :favorites_index
    )
  end

  @spec create_favorite(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create_favorite(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> FrontRepo.insert()
  end

  @spec update_favorite(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update_favorite(%__MODULE__{} = favorite, attrs) do
    favorite
    |> changeset(attrs)
    |> FrontRepo.update()
  end

  @spec delete_favorite(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def delete_favorite(%__MODULE__{} = favorite) do
    FrontRepo.delete(favorite)
  end

  @spec find_by(map()) :: t() | nil
  def find_by(attrs) do
    FrontRepo.get_by(__MODULE__, attrs)
  end

  def list_favorite_by_user_id(user_id, opts) do
    organization_id = Keyword.get(opts, :organization_id, nil)

    query = from(f in __MODULE__, where: f.user_id == ^user_id, select: f)

    query =
      if organization_id && organization_id != "",
        do: where(query, [f], f.organization_id == ^organization_id),
        else: query

    FrontRepo.all(query)
  end

  @spec find_or_create(map()) :: {:ok, t(), :created | :found} | {:error, Ecto.Changeset.t()}
  def find_or_create(attrs) do
    case FrontRepo.get_by(__MODULE__, attrs) do
      nil ->
        case create_favorite(attrs) do
          {:ok, favorite} -> {:ok, favorite, :created}
          error -> error
        end

      favorite ->
        {:ok, favorite, :found}
    end
  end
end
