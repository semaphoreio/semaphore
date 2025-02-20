class AddStateReasonFieldToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :state_reason, :string
  end
end
