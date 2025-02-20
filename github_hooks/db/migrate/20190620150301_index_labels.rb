class IndexLabels < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :labels, [:object_kind, :object_id, :key, :value], algorithm: :concurrently
  end
end
