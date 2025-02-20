class AddLabelsTable < ActiveRecord::Migration[5.0]
  def change
    create_table :labels do |t|
      t.string :object_kind
      t.string :object_id
      t.string :key
      t.string :value
    end
  end
end
