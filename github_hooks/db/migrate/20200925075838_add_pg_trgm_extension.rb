class AddPgTrgmExtension < ActiveRecord::Migration[5.1]
  def change
    enable_extension "pg_trgm"
  end
end
