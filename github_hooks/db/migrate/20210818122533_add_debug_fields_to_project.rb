class AddDebugFieldsToProject < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :debug_empty, :boolean, null: false, default: false
    add_column :projects, :debug_default_branch, :boolean, null: false, default: false
    add_column :projects, :debug_non_default_branch, :boolean, null: false, default: false
    add_column :projects, :debug_pr, :boolean, null: false, default: false
    add_column :projects, :debug_forked_pr, :boolean, null: false, default: false
    add_column :projects, :debug_tag, :boolean, null: false, default: false
    add_column :projects, :attach_default_branch, :boolean, null: false, default: false
    add_column :projects, :attach_non_default_branch, :boolean, null: false, default: false
    add_column :projects, :attach_pr, :boolean, null: false, default: false
    add_column :projects, :attach_forked_pr, :boolean, null: false, default: false
    add_column :projects, :attach_tag, :boolean, null: false, default: false
  end
end
