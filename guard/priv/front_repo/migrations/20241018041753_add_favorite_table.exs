defmodule Guard.FrontRepo.Migrations.AddFavoriteTable do
  use Ecto.Migration

  def change do
    create table(:favorites, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :uuid, null: false
      add :favorite_id, :uuid, null: false
      add :kind, :string, null: false
      add :organization_id, :uuid, null: false
    end

    create unique_index(:favorites, [:user_id, :organization_id, :favorite_id, :kind], name: :favorites_index)
    create index(:favorites, [:user_id, :organization_id], name: :index_favorites_on_user_id_and_organization_id)
  end
end
