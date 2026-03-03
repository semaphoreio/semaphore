class AddExpiresAtToJobs < ActiveRecord::Migration[6.1]
  def change
    add_column :jobs, :expires_at, :datetime, if_not_exists: true
  end
end
