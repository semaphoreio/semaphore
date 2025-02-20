defmodule Gofer.EctoRepo.Migrations.AddMoreFieldsForChangeIn do
  use Ecto.Migration

  def change do
    alter table(:switches) do
      add :yml_file_name,  :string
      add :pr_base, :string
    end
  end
end
