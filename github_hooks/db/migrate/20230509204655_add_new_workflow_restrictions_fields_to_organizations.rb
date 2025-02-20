class AddNewWorkflowRestrictionsFieldsToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :deny_member_workflows, :boolean, null: false, default: false
    add_column :organizations, :deny_non_member_workflows, :boolean, null: false, default: false
  end
end
