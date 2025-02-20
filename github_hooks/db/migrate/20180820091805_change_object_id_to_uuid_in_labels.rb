class ChangeObjectIdToUuidInLabels < ActiveRecord::Migration[5.0]
  def change
    change_column :labels, :object_id, "uuid USING object_id::uuid" # typecast required by postgres
  end
end
