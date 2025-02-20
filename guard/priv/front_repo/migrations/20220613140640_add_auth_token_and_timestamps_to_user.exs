defmodule Guard.FrontRepo.Migrations.AddAuthTokenAndTimestampsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :authentication_token, :string

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end

    create unique_index(:users, :authentication_token, name: :index_users_on_authentication_token)
    create unique_index(:users, :email, name: :index_users_on_email)
  end
end
