defmodule Gofer.EctoRepo.Migrations.AddSwitchesTable do
  use Ecto.Migration

  def change do
    create table(:switches, primary_key: false) do
      add :id,         :uuid,   primary_key: true
      add :ppl_id,     :string
      add :ppl_done,   :boolean, default: false
      add :ppl_result, :string
      add :ppl_result_reason, :string
      add :prev_ppl_artefact_ids,  {:array, :string}
      add :branch_name,  :string

      timestamps()
    end

    create unique_index(:switches, [:ppl_id], name: :unique_ppl_id_for_switch)
  end
end
