defmodule Guard.GitIntegratorRepo.Migrations.CreateIntegrationConfig do
  use Ecto.Migration

  def change do
    create table(:integration_config, primary_key: false) do
      add :name, :string, primary_key: true
      add :config_encrypted, :bytea, default: nil

      timestamps(type: :utc_datetime)
    end
  end
end
