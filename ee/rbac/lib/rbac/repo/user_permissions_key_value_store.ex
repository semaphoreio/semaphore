defmodule Rbac.Repo.UserPermissionsKeyValueStore do
  use Rbac.Repo.Schema

  @primary_key false
  schema "user_permissions_key_value_store" do
    field(:key, :string, primary_key: true)
    field(:value, :string)
    timestamps()
  end
end
