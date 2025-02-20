class AddAnalysisFieldToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :analysis, :jsonb
  end
end
