class AddBuildFlagsToProject < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :build_tag, :boolean, null: false, default: true
    add_column :projects, :build_branch, :boolean, null: false, default: true
    add_column :projects, :build_pr, :boolean, null: false, default: false
    add_column :projects, :build_forked_pr, :boolean, null: false, default: false
  end
end
