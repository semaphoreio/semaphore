defmodule Guard.Repo.Migrations.AddEmailToOktaUsers do
  use Ecto.Migration

  def change do
    alter table(:okta_users) do
      add(:email, :string)
    end

    create unique_index(:okta_users, [:integration_id, :email])
  end

end
