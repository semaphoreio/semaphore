defmodule Guard.FrontRepo.Migrations.AddUserRefsTable do
  use Ecto.Migration

  def change do
    create table(:user_refs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :uuid
      add :entry_url, :string
      add :http_referer, :string
    end

    create index(:user_refs, [:user_id], name: :index_user_refs_on_user_id)
  end
end
