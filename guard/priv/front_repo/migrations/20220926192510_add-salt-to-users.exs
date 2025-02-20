defmodule Guard.FrontRepo.Migrations.AddSaltToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :salt, :string
    end
  end
end
