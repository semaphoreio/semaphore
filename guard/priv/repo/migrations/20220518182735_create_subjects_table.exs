defmodule Guard.Repo.Migrations.CreateSubjectsTable do
  use Ecto.Migration

  def change do
    create table(:subjects)
  end
  
end
