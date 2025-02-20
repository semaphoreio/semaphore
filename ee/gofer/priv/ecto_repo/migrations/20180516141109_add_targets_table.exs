defmodule Gofer.EctoRepo.Migrations.AddTargetsTable do
  use Ecto.Migration

  def change do
    create table(:targets) do
      add :switch_id, references(:switches, type: :uuid), null: false
      add :name,          :string
      add :pipeline_path, :string
      add :predefined_env_vars, :map, default: "{}"
      add :auto_trigger_on, :jsonb, default: "[]"

      timestamps()
    end

    create unique_index(:targets, [:switch_id, :name], name: :uniqe_target_name_per_switch)
  end
end
