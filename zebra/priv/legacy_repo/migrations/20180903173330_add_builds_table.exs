defmodule Zebra.Repo.Migrations.AddBuildsTable do
  use Ecto.Migration

  def change do
    create table(:builds) do
      add :workflow_id, :binary_id
      add :ppl_id, :binary_id
      add :branch_id, :binary_id

      add :result, :string

      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
    end
  end
end
