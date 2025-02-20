class DropUserRefs < ActiveRecord::Migration[5.1]
  def change
    drop_table :user_refs
  end
end
