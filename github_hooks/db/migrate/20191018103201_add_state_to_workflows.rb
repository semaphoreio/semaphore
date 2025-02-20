class AddStateToWorkflows < ActiveRecord::Migration[5.1]
  def change
    add_column :workflows, :state, :string

    add_index "workflows", ["state"]
  end
end
