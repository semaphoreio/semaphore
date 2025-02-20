class IntroduceJobStopRequestsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :job_stop_requests, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.references :job, type: :uuid, index: { unique: true }, foreign_key: true
      t.references :build, type: :uuid, index: true, foreign_key: true

      t.string :state, null: false
      t.string :result
      t.string :result_reason

      t.timestamps null: false
      t.datetime :done_at
    end
  end
end
