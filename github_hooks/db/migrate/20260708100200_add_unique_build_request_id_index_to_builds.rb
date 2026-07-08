class AddUniqueBuildRequestIdIndexToBuilds < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  # No if_not_exists here on purpose: a failed CREATE INDEX CONCURRENTLY leaves
  # an INVALID index behind, and a rerun that silently skips it would leave the
  # uniqueness unenforced. A loud failure prompts dropping the invalid index
  # and rebuilding cleanly.
  def change
    add_index :builds,
              :build_request_id,
              name: "unique_builds_on_build_request_id_not_null",
              algorithm: :concurrently,
              where: "build_request_id IS NOT NULL",
              unique: true
  end
end
