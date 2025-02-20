class AddDispatchedAtToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :dispatched_at, :datetime
  end
end
