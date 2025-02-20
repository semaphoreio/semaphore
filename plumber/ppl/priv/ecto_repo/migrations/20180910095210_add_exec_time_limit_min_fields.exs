defmodule Ppl.EctoRepo.Migrations.AddExecTimeLimitMinFields do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :exec_time_limit_min, :integer
    end
    
    alter table(:pipeline_blocks) do
      add :exec_time_limit_min, :integer
    end
  end
end
