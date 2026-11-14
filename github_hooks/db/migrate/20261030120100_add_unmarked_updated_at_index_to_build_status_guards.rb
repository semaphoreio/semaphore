class AddUnmarkedUpdatedAtIndexToBuildStatusGuards < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :build_status_guards,
              :updated_at,
              name: "build_status_guards_unmarked_updated_at_index",
              algorithm: :concurrently,
              where: "has_check_run IS NOT TRUE",
              if_not_exists: true
  end
end
