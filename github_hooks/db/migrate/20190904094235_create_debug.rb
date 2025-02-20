class CreateDebug < ActiveRecord::Migration[5.1]
  def change
    create_table :debugs, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.uuid :job_id, null: false
      t.uuid :debugged_id, null: false
      t.string :debugged_type, null: false
    end

    add_index :debugs, :job_id
    add_index :debugs, [:debugged_type, :debugged_id]
  end
end
