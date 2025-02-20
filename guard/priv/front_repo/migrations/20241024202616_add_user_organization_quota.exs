defmodule Guard.FrontRepo.Migrations.AddUserOrganizationQuota do
  use Ecto.Migration

  def change do
    create table(:quotas, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :organization_id, references(:organizations, type: :uuid)
      add :type, :string
      add :value, :integer
    end

    create unique_index(:quotas, [:organization_id, :type], name: :index_quotas_on_organization_id_and_type)
    create index(:quotas, [:organization_id], name: :index_quotas_on_organization_id)
    create index(:quotas, [:type], name: :index_quotas_on_type)
  end
end
