class AddUniqueIndexForUserIdemptotencyTokens < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :users, :idempotency_token, name: "users_idempotency_token_index", unique: true, algorithm: :concurrently, where: "idempotency_token IS NOT NULL"
  end
end
