class AddRunOnDraftPrsForProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :build_draft_pr, :boolean, null: false, default: true
  end
end
