class InitialMigration < ActiveRecord::Migration[4.2]
  enable_extension "uuid-ossp"

  def change
    create_table "branches", force: :cascade, id: :uuid do |t|
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.uuid     "project_id"
      t.string   "slug"
      t.integer  "pull_request_number"
      t.string   "pull_request_name"
      t.boolean  "pull_request_mergeable"
    end

    add_index "branches", ["project_id", "name"], name: "index_branches_on_project_id_and_name", unique: true, using: :btree
    add_index "branches", ["project_id"], name: "index_branches_on_project_id", using: :btree
    add_index "branches", ["slug"], name: "index_branches_on_slug", using: :btree

    create_table "build_servers", force: :cascade, id: :uuid do |t|
      t.string   "name"
      t.string   "ip_address"
      t.integer  "core_count"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean  "enabled",              default: false
      t.text     "metadata"
      t.datetime "last_job_assigned_at"
    end

    create_table "builds", force: :cascade, id: :uuid do |t|
      t.string   "version",                          null: false
      t.jsonb    "request",                          null: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.uuid     "repo_host_post_commit_request_id", null: false
      t.uuid     "ppl_id",                           null: false
      t.uuid     "branch_id"
      t.uuid     "build_request_id"
      t.string   "result"
    end

    add_index "builds", ["repo_host_post_commit_request_id"], name: "index_builds_on_repo_host_post_commit_request_id", using: :btree

    create_table "containers", force: :cascade, id: :uuid do |t|
      t.uuid     "job_id"
      t.string   "aasm_state"
      t.uuid     "build_server_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "cores"
    end

    add_index "containers", ["aasm_state"], name: "index_containers_on_aasm_state", where: "((aasm_state)::text = 'occupied'::text)", using: :btree
    add_index "containers", ["build_server_id"], name: "index_containers_on_build_server_id", using: :btree
    add_index "containers", ["job_id"], name: "index_containers_on_job_id", using: :btree

    create_table "deploy_keys", force: :cascade, id: :uuid do |t|
      t.text     "private_key"
      t.text     "public_key"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.uuid     "project_id"
      t.boolean  "deployed",    default: false
      t.integer  "remote_id"
    end

    add_index "deploy_keys", ["project_id"], name: "index_deploy_keys_on_project_id", using: :btree

    create_table "jobs", force: :cascade, id: :uuid do |t|
      t.string   "aasm_state"
      t.datetime "enqueued_at"
      t.datetime "scheduled_at"
      t.datetime "started_at"
      t.datetime "finished_at"
      t.uuid     "build_server_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.jsonb    "request"
      t.string   "previous_aasm_state"
      t.boolean  "open_source",          default: false
      t.integer  "required_cores"
      t.datetime "server_assigned_at"
      t.datetime "teardown_finished_at"
      t.string   "name"
      t.string   "result"
      t.uuid     "organization_id"
      t.uuid     "build_id"
      t.integer  "index"
      t.string   "failure_reason"
    end

    add_index "jobs", ["aasm_state"], name: "index_jobs_on_aasm_state", where: "((aasm_state)::text = ANY ((ARRAY['pending'::character varying, 'enqueued'::character varying, 'scheduled'::character varying, 'started'::character varying, 'stopping'::character varying])::text[]))", using: :btree
    add_index "jobs", ["build_server_id"], name: "index_jobs_on_build_server_id", using: :btree
    add_index "jobs", ["organization_id"], name: "index_jobs_on_organization_id", using: :btree

    create_table "oauth_connections", force: :cascade, id: :uuid do |t|
      t.string   "provider"
      t.string   "github_uid"
      t.uuid     "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string   "token"
    end

    create_table "organizations", force: :cascade, id: :uuid do |t|
      t.string   "name"
      t.string   "username"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "gravatar_email"
      t.integer  "box_limit"
      t.uuid     "creator_id"
    end

    add_index "organizations", ["creator_id"], name: "index_organizations_on_creator_id", using: :btree

    create_table "projects", force: :cascade, id: :uuid do |t|
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "slug"
      t.uuid     "creator_id"
      t.datetime "cache_version"
      t.uuid     "organization_id"
    end

    add_index "projects", ["creator_id"], name: "index_projects_on_creator_id", using: :btree
    add_index "projects", ["slug"], name: "index_projects_on_slug", using: :btree

    create_table "repo_host_accounts", force: :cascade, id: :uuid do |t|
      t.string   "token"
      t.string   "name"
      t.string   "login"
      t.string   "permission_scope"
      t.string   "repo_host"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.uuid     "user_id"
      t.string   "secret"
      t.string   "github_uid"
    end

    add_index "repo_host_accounts", ["user_id"], name: "index_repo_host_accounts_on_user_id", using: :btree

    create_table "repo_host_post_commit_requests", force: :cascade, id: :uuid do |t|
      t.uuid     "project_id"
      t.jsonb    "request"
      t.uuid     "build_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "result"
    end

    add_index "repo_host_post_commit_requests", ["build_id"], name: "index_repo_host_post_commit_requests_on_build_id", using: :btree
    add_index "repo_host_post_commit_requests", ["project_id"], name: "index_repo_host_post_commit_requests_on_project_id", using: :btree

    create_table "repositories", force: :cascade, id: :uuid do |t|
      t.string   "hook_id"
      t.string   "name"
      t.string   "owner"
      t.boolean  "private"
      t.string   "provider"
      t.string   "url"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.uuid     "project_id"
      t.boolean  "enable_commit_status", default: true
    end

    add_index "repositories", ["project_id"], name: "index_repositories_on_project_id", using: :btree

    create_table "roles", force: :cascade, id: :uuid do |t|
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "roles_users", id: false, force: :cascade do |t|
      t.uuid  "role_id"
      t.uuid  "user_id"
    end

    add_index "roles_users", ["role_id", "user_id"], name: "index_roles_users_on_role_id_and_user_id", using: :btree

    create_table "taggings", force: :cascade do |t|
      t.integer  "tag_id"
      t.uuid     "taggable_id"
      t.string   "taggable_type"
      t.uuid     "tagger_id"
      t.string   "tagger_type"
      t.string   "context",       limit: 128
      t.datetime "created_at"
    end

    add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true, using: :btree
    add_index "taggings", ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context", using: :btree

    create_table "tags", force: :cascade do |t|
      t.string  "name"
      t.integer "taggings_count", default: 0
    end

    add_index "tags", ["name"], name: "index_tags_on_name", unique: true, using: :btree

    create_table "terminations", force: :cascade, id: :uuid do |t|
      t.uuid     "build_request_id", null: false
      t.string   "aasm_state"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.datetime "processed_at"
    end

    create_table "users", force: :cascade, id: :uuid do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "email"
      t.string   "time_zone",            default: "UTC"
      t.string   "salt"
      t.string   "encrypted_password",   default: "",    null: false
      t.datetime "remember_created_at"
      t.integer  "sign_in_count",        default: 0
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.string   "current_sign_in_ip"
      t.string   "last_sign_in_ip"
      t.string   "authentication_token"
      t.string   "referer"
      t.string   "name"
      t.string   "username"
      t.datetime "confirmation_sent_at"
    end

    add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree
    add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
    add_index "users", ["username"], name: "index_users_on_username", using: :btree
  end
end
