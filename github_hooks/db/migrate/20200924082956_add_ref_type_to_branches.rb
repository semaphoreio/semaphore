class AddRefTypeToBranches < ActiveRecord::Migration[5.1]
  def change
    add_column :branches, :ref_type, :string
  end
end
