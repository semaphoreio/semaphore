class AddPublicToProject < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :public, :boolean, null: false, default: false
  end
end
