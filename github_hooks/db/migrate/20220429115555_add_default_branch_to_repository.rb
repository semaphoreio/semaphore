class AddDefaultBranchToRepository < ActiveRecord::Migration[5.1]

  def change
    add_column :repositories, :default_branch, :string, default: "master", null: false
  end
end
