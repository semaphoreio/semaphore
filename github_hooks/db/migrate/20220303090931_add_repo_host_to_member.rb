class AddRepoHostToMember < ActiveRecord::Migration[5.1]
  def change
    add_column :members, :repo_host, :string
  end
end
