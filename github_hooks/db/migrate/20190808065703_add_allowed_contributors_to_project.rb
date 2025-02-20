class AddAllowedContributorsToProject < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :allowed_contributors, :string, null: false, default: ""
  end
end
