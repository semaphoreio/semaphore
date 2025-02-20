class AddFieldsToWorkflows < ActiveRecord::Migration[5.1]
  def change
    add_column :workflows, :provider, :string
    add_column :workflows, :repository_id, :uuid
    add_column :workflows, :organization_id, :uuid
    add_column :workflows, :received_at, :datetime
    add_column :workflows, :wf_id, :uuid
  end
end
