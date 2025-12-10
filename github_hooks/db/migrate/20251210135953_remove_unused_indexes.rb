class RemoveUnusedIndexes < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    remove_index :jobs, name: "index_jobs_on_project_id_and_created_at", algorithm: :concurrently, if_exists: true
    remove_index :jobs, name: "index_jobs_on_build_server_id", algorithm: :concurrently, if_exists: true
    remove_index :workflows, name: "index_workflows_on_ppl_id", algorithm: :concurrently, if_exists: true
    remove_index :labels, name: "index_labels_on_object_kind_and_object_id_and_key_and_value", algorithm: :concurrently, if_exists: true
    remove_index :job_stop_requests, name: "index_job_stop_requests_on_build_id", algorithm: :concurrently, if_exists: true
    remove_index :branches, name: "index_branches_on_project_id_and_used_at", algorithm: :concurrently, if_exists: true
    remove_index :jobs, name: "index_jobs_on_organization_id_and_created_at", algorithm: :concurrently, if_exists: true
    remove_index :builds, name: "index_builds_on_workflow_id", algorithm: :concurrently, if_exists: true
    remove_index :workflows, name: "one_hook_received_at_per_repository", algorithm: :concurrently, if_exists: true
    remove_index :branches, name: "index_branches_on_archived_at", algorithm: :concurrently, if_exists: true
  end
end
