class AddHasCheckRunToBuildStatusGuards < ActiveRecord::Migration[8.0]
  def change
    add_column :build_status_guards, :has_check_run, :boolean, null: true
  end
end
