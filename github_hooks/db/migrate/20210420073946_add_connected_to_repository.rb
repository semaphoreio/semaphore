class AddConnectedToRepository < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :connected, :boolean, null: false, default: true
  end
end
