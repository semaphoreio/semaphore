class CreateServiceAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :service_accounts, id: false do |t|
      t.uuid :id, primary_key: true, null: false
      t.string :description
      t.uuid :creator_id
    end

    add_foreign_key :service_accounts, :users, column: :id, on_delete: :cascade
    add_foreign_key :service_accounts, :users, column: :creator_id, on_delete: :nullify
  end
end
