defmodule Gofer.EctoRepo.Migrations.AddCordonedFlagToDeployments do
  use Ecto.Migration

  def change do
    alter table(:deployments) do
      add :cordoned, :boolean, null: false, default: false
    end
  end
end
