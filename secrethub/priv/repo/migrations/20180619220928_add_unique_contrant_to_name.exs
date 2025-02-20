defmodule Secrethub.Repo.Migrations.AddUniqueContrantToName do
  use Ecto.Migration

  def change do
    create unique_index(:secrets, [:org_id, :name], name: :unique_names_in_organization)
  end
end
