defmodule Guard.FrontRepo.Migrations.AddUserOrganizationContacts do
  use Ecto.Migration

  def change do
      create table(:organization_contacts, primary_key: false) do
        add :id, :uuid, primary_key: true
        add :organization_id, references(:organizations, type: :uuid), null: false
        add :contact_type, :string
        add :name, :string
        add :email, :string
        add :phone, :string
      end

      create unique_index(:organization_contacts, [:organization_id, :contact_type], name: :index_organization_contacts_on_organization_id_and_contact_type)
      create index(:organization_contacts, [:organization_id], name: :index_organization_contacts_on_organization_id)
    end
end
