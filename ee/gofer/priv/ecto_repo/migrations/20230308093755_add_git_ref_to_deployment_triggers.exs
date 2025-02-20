defmodule Gofer.EctoRepo.Migrations.AddGitRefToDeploymentTriggers do
  use Ecto.Migration

  def change do
    alter table(:deployments) do
      modify :description, :text, null: true
      modify :url, :text, null: true

      add :bookmark_parameter1, :string
      add :bookmark_parameter2, :string
      add :bookmark_parameter3, :string
    end

    alter table(:deployment_triggers) do
      add :git_ref_type, :string
      add :git_ref_label, :string

      add :parameter1, :string
      add :parameter2, :string
      add :parameter3, :string
    end
  end
end
