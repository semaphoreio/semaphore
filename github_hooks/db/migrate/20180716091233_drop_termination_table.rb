class DropTerminationTable < ActiveRecord::Migration[4.2]
  def change
    drop_table :terminations
  end
end
