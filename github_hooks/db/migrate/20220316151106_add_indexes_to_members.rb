class AddIndexesToMembers < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :members, [:github_uid, :organization_id, :repo_host],
      name: "members_organization_repo_host_uid_index",
      unique: true,
      algorithm: :concurrently
  end
end
