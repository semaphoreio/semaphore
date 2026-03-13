class AddSemApproveIncludeFlagsToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :allow_sem_approve_include_secrets, :boolean, null: false, default: false
    add_column :projects, :allow_sem_approve_include_cache, :boolean, null: false, default: false
  end
end
