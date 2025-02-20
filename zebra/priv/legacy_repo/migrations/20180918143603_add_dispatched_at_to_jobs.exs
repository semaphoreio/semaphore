defmodule Zebra.Repo.Migrations.AddDispatchedAtToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :dispatched_at, :utc_datetime
    end
  end
end
