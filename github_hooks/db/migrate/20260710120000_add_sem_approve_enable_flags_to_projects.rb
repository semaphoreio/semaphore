class AddSemApproveEnableFlagsToProjects < ActiveRecord::Migration[7.0]
  def up
    add_column :projects, :allow_sem_approve_include_secrets, :boolean, null: false, default: false, if_not_exists: true
    add_column :projects, :allow_sem_approve_enable_cache, :boolean, null: false, default: false, if_not_exists: true
  end

  def down
    remove_column :projects, :allow_sem_approve_include_secrets, if_exists: true
    remove_column :projects, :allow_sem_approve_enable_cache, if_exists: true
  end
end
