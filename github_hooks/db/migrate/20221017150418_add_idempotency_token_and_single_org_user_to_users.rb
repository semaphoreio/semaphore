class AddIdempotencyTokenAndSingleOrgUserToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :idempotency_token, :string
    add_column :users, :single_org_user, :boolean
    add_column :users, :creation_source, :string
    add_column :users, :org_id, :uuid
  end
end
