class AddIntegrationTypeToRepository < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :integration_type, :string
  end
end
