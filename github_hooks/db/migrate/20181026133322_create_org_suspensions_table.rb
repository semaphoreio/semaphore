class CreateOrgSuspensionsTable < ActiveRecord::Migration[4.2]
  def change
    create_table :organization_suspensions, id: :uuid do |t|
      t.references :organization, type: :uuid, index: true, foreign_key: true

      t.string :reason
      t.string :origin
      t.text :description

      t.timestamps null: false
    end

    add_index :organization_suspensions, [:organization_id, :reason], unique: true
  end
end
