class RemoveTagsAndTaggings < ActiveRecord::Migration[5.1]
  def change
    rename_table(:tags, :ducks)
    rename_table(:taggings, :pigeons)
  end
end
