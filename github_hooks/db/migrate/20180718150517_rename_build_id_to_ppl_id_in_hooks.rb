class RenameBuildIdToPplIdInHooks < ActiveRecord::Migration[4.2]
  def change
    rename_column :repo_host_post_commit_requests, :build_id, :ppl_id
  end
end
