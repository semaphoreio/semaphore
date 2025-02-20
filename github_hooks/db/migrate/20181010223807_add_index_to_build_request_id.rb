class AddIndexToBuildRequestId < ActiveRecord::Migration[5.1]
  def change
    add_index "builds", ["build_request_id"], name: "index_build_request_ids_on_builds", unique: true, using: :btree
  end
end
