class CreateOrganizationContacts < ActiveRecord::Migration[5.1]
  def change
    create_table :organization_contacts, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.references :organization, type: :uuid, index: true, foreign_key: true, null: false
      t.string "contact_type"
      t.string "name"
      t.string "email"
      t.string "phone"
    end

    add_index :organization_contacts, [:organization_id, :contact_type], unique: true
  end
end
