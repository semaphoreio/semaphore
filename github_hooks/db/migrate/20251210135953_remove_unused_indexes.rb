class RemoveUnusedIndexes < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
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

  def down
    add_index :jobs, [:project_id, :created_at], order: {created_at: "DESC"}, algorithm: :concurrently
    add_index :jobs, [:build_server_id], name: "index_jobs_on_build_server_id", algorithm: :concurrently
    add_index :workflows, [:ppl_id], name: "index_workflows_on_ppl_id", algorithm: :concurrently
    add_index :labels, [:object_kind, :object_id, :key, :value], algorithm: :concurrently
    add_index :job_stop_requests, [:build_id], name: "index_job_stop_requests_on_build_id", algorithm: :concurrently
    add_index :branches, [:project_id, :used_at], order: {used_at: "DESC"}, algorithm: :concurrently
    add_index :jobs, [:organization_id, :created_at], order: {created_at: "DESC"}, algorithm: :concurrently
    add_index :builds, [:workflow_id], name: "index_builds_on_workflow_id", algorithm: :concurrently
    add_index :workflows, [:repository_id, :received_at], where: "repository_id IS NOT NULL", name: "one_hook_received_at_per_repository", algorithm: :concurrently
    add_index :branches, [:archived_at], algorithm: :concurrently
  end
end
