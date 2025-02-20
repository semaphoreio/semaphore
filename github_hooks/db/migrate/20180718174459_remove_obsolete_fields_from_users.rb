class RemoveObsoleteFieldsFromUsers < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :encrypted_password
    remove_column :users, :referer
    remove_column :users, :confirmation_sent_at
  end
end
