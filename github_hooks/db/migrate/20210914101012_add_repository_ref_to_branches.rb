class AddRepositoryRefToBranches < ActiveRecord::Migration[5.1]
  def change
    add_column :branches, :repository_id, :uuid
  end
end
