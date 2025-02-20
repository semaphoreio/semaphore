defmodule Rbac.Repo.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field(:user_id, :binary_id)
    field(:github_uid, :string)
    field(:provider, :string)

    timestamps(type: :naive_datetime_usec)
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:user_id, :github_uid, :provider])
    |> validate_required([:user_id, :github_uid, :provider])
    |> unique_constraint(:github_uid, name: :unique_githubber)
  end
end
