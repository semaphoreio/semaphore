class AddDescriptionToProject < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :description, :string, default: "", null: false
  end
end
