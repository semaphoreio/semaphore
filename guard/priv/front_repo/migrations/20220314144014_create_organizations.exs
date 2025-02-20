defmodule Guard.FrontRepo.Migrations.Organization do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :username, :string
      add :box_limit, :integer
      add :creator_id, :binary_id
      add :suspended, :boolean
      add :open_source, :boolean
      add :restricted, :boolean, default: false

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end
  end
end
