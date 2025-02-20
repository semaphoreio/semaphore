class AddIndexForProjectsOnJobs < ActiveRecord::Migration[5.1]
  def change
    add_index "jobs", ["project_id"], name: "index_jobs_on_project_id", using: :btree
  end
end
