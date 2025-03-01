defmodule Guard.Repo.Migrations.AddJitProvisioningField do
  use Ecto.Migration

  def change do
    alter table(:okta_integrations) do
      add :jit_provisioning_enabled, :boolean, default: false, null: false
    end
  end
end
