defmodule Zebra.Repo.Migrations.AddRequestToJob do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :request, :map
    end
  end
end
