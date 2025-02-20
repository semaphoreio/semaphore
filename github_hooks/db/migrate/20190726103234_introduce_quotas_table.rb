class IntroduceQuotasTable < ActiveRecord::Migration[5.1]
  def change
    create_table :quotas, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.references :organization, index: true, foreign_key: true, type: :uuid
      t.string "type", index: true
      t.integer "value"
    end
  end
end
