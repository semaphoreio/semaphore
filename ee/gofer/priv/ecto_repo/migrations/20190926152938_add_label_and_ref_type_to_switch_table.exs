defmodule Gofer.EctoRepo.Migrations.AddLabelAndRefTypeToSwitchTable do
  use Ecto.Migration

  def change do
    alter table(:switches) do
      add :label,  :string
      add :git_ref_type, :string
    end

    alter table(:targets) do
      add :auto_promote_when, :string
    end
  end
end
