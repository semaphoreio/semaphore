defmodule Gofer.EctoRepo.Migrations.AddPrShaToSwitchesTable do
  use Ecto.Migration

  def change do
    alter table(:switches) do
      add :pr_sha,  :string
    end
  end
end
