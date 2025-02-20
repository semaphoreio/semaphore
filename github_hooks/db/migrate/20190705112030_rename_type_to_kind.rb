class RenameTypeToKind < ActiveRecord::Migration[5.1]
  def change
    rename_column :favorites, :type, :kind
  end
end
