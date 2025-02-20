class AddHookIdToBuilds < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :hook_id, :uuid
  end
end
