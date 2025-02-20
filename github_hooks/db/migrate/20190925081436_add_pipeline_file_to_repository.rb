class AddPipelineFileToRepository < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :pipeline_file, :string, default: ".semaphore/semaphore.yml"
  end
end
