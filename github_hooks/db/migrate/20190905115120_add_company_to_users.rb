class AddCompanyToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :company, :string
  end
end
