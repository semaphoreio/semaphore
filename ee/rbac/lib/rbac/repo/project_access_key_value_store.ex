defmodule Rbac.Repo.ProjectAccessKeyValueStore do
  use Rbac.Repo.Schema

  @primary_key false
  schema "project_access_key_value_store" do
    field(:key, :string, primary_key: true)
    field(:value, :string)
    timestamps()
  end
end
