defmodule Gofer.EctoRepo.Migrations.ChangePredefEnvVarsToParamEnvVars do
  use Ecto.Migration

  def change do
    alter table(:targets) do
      remove :predefined_env_vars
      add :parameter_env_vars, :jsonb, default: "{}"
    end
  end
end
