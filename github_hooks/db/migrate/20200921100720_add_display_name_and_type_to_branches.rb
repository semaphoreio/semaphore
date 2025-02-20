class AddDisplayNameAndTypeToBranches < ActiveRecord::Migration[5.1]
  def change
    add_column :branches, :display_name, :string
    add_column :branches, :type, :string
  end
end
