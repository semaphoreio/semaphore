class AddSpecToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :spec, :jsonb
  end
end
