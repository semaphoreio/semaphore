class RemoveEaglesFalconsDucksAndPigeonsTables < ActiveRecord::Migration[5.1]
  def change
    drop_table :eagles
    drop_table :falcons
    drop_table :ducks
    drop_table :pigeons
  end
end
