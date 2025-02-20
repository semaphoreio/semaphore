class DropQuotas < ActiveRecord::Migration[5.1]
  def change
    drop_table :quotas
  end
end
